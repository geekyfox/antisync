require 'digest'

module Antisync
  ##
  # Module for parsing Antiblog's markup language.
  #
  module Parser
    ##
    # Parsed entry.
    #
    class Entry
      attr_accessor :content
      attr_accessor :metalink
      attr_accessor :redirect_url
      attr_accessor :summary
      attr_accessor :symlink
      attr_accessor :title

      attr_reader :public_id
      attr_reader :series
      attr_reader :tags

      def initialize
        @series = []
        @tags = []
        @publish = false
      end

      def public_id=(id)
        @public_id = (id.nil? ? nil : id.to_i)
        @publish = true
      end

      def publish?
        @publish
      end

      def new?
        @public_id.nil?
      end

      def to_h
        hash = redirect_hash || content_hash
        hash[:signature] = Antisync::Parser.signature(hash)
        hash[:id] = @public_id if @public_id
        hash
      end

      def md5
        to_h[:signature]
      end

      def redirect_hash
        return unless @redirect_url
        {
          url: @redirect_url
        }
      end

      def content_hash
        h = {
          body: @content,
          series: @series
        }
        h[:title] = @title if @title
        h[:symlink] = @symlink if @symlink
        h[:summary] = @summary if @summary
        h[:tags] = @tags if @tags
        h[:metalink] = @metalink if @metalink
        h
      end

      def to_json
        to_h.to_json
      end

      def freeze
        @series.freeze
        super
      end
    end

    class ParseError < RuntimeError
    end

    ##
    # Buffer with lines of text.
    #
    class LineBuffer < Array
      def start
      end

      def finish
      end

      def strip
        shift until empty? || meaningful?(self[0])
        pop until empty? || meaningful?(self[-1])
      end

      def meaningful?(line)
        return false if line == :blank_line
        return false if line == :separator
        true
      end

      TRANSLATION_TABLE = {
        blank_line: "\n",
        separator: "</div><div class=\"stuff\">\n"
      }.freeze

      def format
        strip
        return nil if empty?
        map { |line| TRANSLATION_TABLE[line] || line }.join('')
      end
    end

    ##
    # Helper class for processing <tt>~ content</tt> sections.
    #
    class ContentWriter
      def initialize(buffer)
        @buffer = buffer
      end

      def start
      end

      def <<(line)
        @buffer << (line.strip.empty? ? :separator : line)
      end

      def finish
      end
    end

    ##
    # Helper class for processing <tt>~ poem</tt> sections.
    #
    class PoemWriter
      def initialize(buffer)
        @buffer = buffer
      end

      def start
        @buffer << :separator
      end

      def <<(line)
        if line.strip.empty?
          @buffer << :blank_line << :separator
        else
          @buffer << "<br />\n" unless @buffer[-1] == :separator
          @buffer << line.rstrip
        end
      end

      def finish
        @buffer << :blank_line << :separator
      end
    end

    ##
    # Helper class for processing <tt>~ code</tt> sections.
    #
    class CodeWriter
      def initialize(buffer)
        @buffer = buffer
      end

      def start
        @buffer << "<pre>\n"
      end

      def <<(line)
        @buffer << (line.strip.empty? ? :blank_line : line)
      end

      def finish
        @buffer << "</pre>\n"
      end
    end

    ##
    # Helper class for processing <tt>~ footnote</tt> sections.
    #
    class FooterBuffer < Array
      def initialize(buffer)
        @buffer = buffer
        @count = 0
      end

      def start
        @buffer[-1].strip! unless @buffer.empty?
        self << '<br />' unless @count.zero?
        @count += 1
        @buffer << format_ref('tx', 'nm')
        self << format_ref('nm', 'tx')
      end

      def finish
      end

      def format_ref(name_prefix, href_prefix)
        ix = @count.to_s
        nm = name_prefix + ix
        hr = href_prefix + ix
        "<a name='#{nm}' href='\##{hr}'><sup>#{ix}</sup></a>"
      end

      def dump
        @buffer << "\n<hr />\n" << join("\n") unless empty?
      end
    end

    ##
    # Builder for entry's content.
    #
    class ContentBuilder
      attr_reader :result

      def initialize
        @primary_buffer = LineBuffer.new
        @summary_buffer = LineBuffer.new
        @summary = ContentWriter.new(@summary_buffer)
        @content = ContentWriter.new(@primary_buffer)
        @footer = FooterBuffer.new(@primary_buffer)
        @poem = PoemWriter.new(@primary_buffer)
        @code = CodeWriter.new(@primary_buffer)

        @target = @content
      end

      def insert_summary
        @primary_buffer.concat(@summary_buffer)
      end

      def switch_to(mode)
        method = "switch_to_#{mode}".to_sym
        if self.class.method_defined?(method)
          public_send(method)
          true
        else
          false
        end
      end

      def switch_to_code
        self.target = @code
      end

      def switch_to_content
        self.target = @content
      end

      def switch_to_footnote
        self.target = @footer
      end

      def switch_to_poem
        self.target = @poem
      end

      def switch_to_summary
        self.target = @summary
      end

      def target=(buffer)
        @target.finish
        @target = buffer
        @target.start
      end

      def <<(line)
        @target << line
      end

      def export
        @footer.dump
        content = @primary_buffer.format
        raise ParseError, 'No content' unless content
        summary = @summary_buffer.format
        {
          content: content, summary: summary
        }
      end
    end

    ##
    # Parser implementation.
    #
    class Parser
      attr_reader :result

      def initialize(target)
        @target = target
        @builder = ContentBuilder.new
        @result = Entry.new
        @line_count = 0
      end

      def error(msg)
        raise ParseError, "#{msg} at line #{@line_count}"
      end

      def duplicate(item)
        error("Multiple '~ #{item}'")
      end

      def export
        x = @builder.export
        @result.content = x[:content]
        @result.summary = x[:summary]
        @result.freeze
      end

      def <<(line)
        @line_count += 1
        if line.start_with? '~'
          tokens = line.split(' ')
          tokens.shift
          cmd = tokens.shift
          handle_directive(cmd, tokens)
        else
          @builder << line
        end
        self
      end

      def handle_directive(cmd, args)
        return if @builder.switch_to(cmd)
        interpret = "interpret_#{cmd}".tr('-', '_').to_sym
        if Parser.method_defined?(interpret)
          public_send(interpret, *args)
        else
          error("Unsupported directive '#{cmd}'")
        end
      rescue ArgumentError
        error("Bad number of arguments for '#{cmd}'")
      end

      def interpret_insert_summary
        @builder.insert_summary
      end

      def interpret_meta(token)
        if @result.metalink
          duplicate('metalink')
        else
          @result.metalink = token
        end
      end

      def interpret_public(target, id = nil)
        return unless target == @target
        duplicate("public #{@target}") if @result.publish?
        @result.public_id = id
      end

      def interpret_redirect(target, url)
        return unless target == @target
        duplicate("redirect #{@target}") if @result.redirect_url
        @result.redirect_url = url
      end

      def interpret_tags(*tokens)
        @result.tags.concat(tokens)
      end

      def interpret_series(series, index)
        @result.series << { series: series, index: index.to_i }
      end

      def interpret_symlink(token)
        duplicate('symlink') if @result.symlink
        @result.symlink = token
      end

      def interpret_title(*tokens)
        @result.title = tokens.join(' ')
      end
    end

    def self.load(target, filename)
      x = Parser.new(target)
      File.open(filename, 'r') do |f|
        f.each_line { |line| x << line }
      end
      x.export
    end

    def self.inject_id(target, filename, id)
      search = "~ public #{target}"
      replace = "~ public #{target} #{id}\n"
      lines = File.open(filename, 'r', &:readlines).map do |line|
        line.strip == search ? replace : line
      end
      File.open(filename, 'w') do |f|
        lines.each { |line| f.write(line) }
      end
    end

    def self.signature(value, digest = nil)
      digest ||= Digest::MD5.new
      case value
      when Hash
        value.keys.sort.each { |key| signature(value[key], digest) }
      when Array
        value.each { |elem| signature(elem, digest) }
      else
        digest << value.to_s
      end
      digest.hexdigest
    end
  end
end
