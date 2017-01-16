require 'English'

module Antisync
  ##
  # Module for parsing command-line arguments of +antisync+.
  #
  module CmdArgs
    ##
    # Options that +antisync+ may have.
    #
    class Options
      attr_accessor :command, :verbose, :target, :config
      attr_writer :files

      def initialize
        @command = nil
        # Arguments
        @target = nil
        @files = nil
        # Flags
        @verbose = false
        @config = '~/.antisync.conf'
      end

      def files
        if @files.nil? || @files.empty?
          ['.']
        else
          @files
        end
      end
    end

    class ParseError < RuntimeError
    end

    ##
    # Parser of command-line arguments.
    #
    class Parser
      def initialize
        @result = Options.new
        @params = []
      end

      def apply_flag(key, value)
        method = "#{key}=".to_sym
        unless Options.method_defined?(method)
          raise ParseError, "Unknown flag: '#{key}'"
        end
        @result.public_send(method, value)
      end

      def prepare(args)
        args.each do |x|
          if /^--([^=]+)=(.+)$/ =~ x
            apply_flag($LAST_MATCH_INFO[1], $LAST_MATCH_INFO[2])
          elsif /^--([^=]+)$/ =~ x
            apply_flag($LAST_MATCH_INFO[1], true)
          else
            @params << x
          end
        end
      end

      def shift_or_raise(msg)
        raise ParseError, msg if @params.empty?
        @params.shift
      end

      def parse_status
        @result.target = shift_or_raise(
          "<target> parameter is mandatory in 'status' command"
        )
        @result.files = @params
      end

      def parse_push
        @result.target = shift_or_raise(
          "<target> parameter is mandatory in 'push' command"
        )
        @result.files = @params
      end

      def parse_help
      end

      def parse
        command = @params.shift || 'help'
        method = "parse_#{command}".to_sym
        unless Parser.method_defined?(method)
          raise ParseError, "Unknown command: '#{command}'"
        end
        @result.command = command.to_sym
        public_send(method)
        @result.freeze
      end
    end

    def self.parse(args = nil)
      Parser.new.tap { |x| x.prepare(args || ARGV) }.parse
    end
  end
end
