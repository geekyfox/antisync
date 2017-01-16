
require 'net/http'
require 'set'
require 'json'

require_relative 'antisync/parser'
require_relative 'antisync/cmdargs'

##
# Command-line client for Antiblog.
#
module Antisync
  ##
  # Printed when executing +help+ command.
  #
  HELP_BANNER = %(
  Usage: antisync [--verbose] [--config=<config file>] <command> [<args>]

  where
    <command> is one of:
      * status
      * push
      * help
  ).lstrip.freeze

  ##
  # Recursively scanned list of files.
  #
  class FileSet
    def initialize(files = [])
      @files = []
      @seen = Set.new
      files.each { |x| self << x }
    end

    def <<(x)
      return self unless @seen.add?(x)
      if File.directory?(x)
        Dir.foreach(x) do |y|
          next if y.start_with?('.')
          self << (x == '.' ? y : File.join(x, y))
        end
      else
        @files << x
      end
      self
    end

    def each
      @files.each { |x| yield x }
    end
  end

  ##
  # Configuration parameters.
  #
  class Config
    attr_reader :base_url
    attr_reader :api_key

    def initialize(params)
      data = File.open(File.expand_path(params.config), 'r', &:read)
      JSON.parse(data).each do |entry|
        next unless entry['name'] == params.target
        @base_url = entry['url']
        @api_key = entry['api_key']
        break
      end
      raise "Configuration for #{@target} not found" if @base_url.nil?
    end

    def self.make(params)
      return nil if params.target.nil?
      new(params)
    end
  end

  ##
  # Helper class for communicating with user.
  #
  class Talker
    attr_writer :headless, :verbose

    def initialize
      @headless = false
      @verbose = true
    end

    def say(message)
      return if @headless
      puts message
    end

    def babble(message)
      say(message) if @verbose
    end

    def ok(message)
      say("[OK] #{message}")
    end
  end

  ##
  # API client.
  #
  class HttpClient
    def initialize(config)
      @config = config
      @index = nil
    end

    def index
      return @index unless @index.nil?
      http_get('/api/index') do |x|
        result = {}
        x.each do |entry|
          result[entry['id']] = entry['signature']
        end
        @index = result
      end
    end

    def create(entry)
      http_post('/api/create', entry) { |r| yield r['id'] }
    end

    def update(entry)
      http_post('/api/update', entry) { |_| yield }
    end

    def http_get(endpoint, &block)
      uri = URI(@config.base_url + endpoint)
      params = { api_key: @config.api_key }
      uri.query = URI.encode_www_form(params)
      res = Net::HTTP.get_response(uri)
      handle_response(res, &block)
    end

    def http_post(endpoint, payload, &block)
      uri = URI(@config.base_url + endpoint)
      res = Net::HTTP.post_form(
        uri,
        payload: payload.to_json,
        api_key: @config.api_key
      )
      handle_response(res, &block)
    end

    def handle_response(response)
      case response
      when Net::HTTPSuccess then
        yield JSON.parse(response.body)
      when Net::HTTPForbidden then
        raise response.body
      else
        raise "Bad response: #{response} | #{response.body}"
      end
    end
  end

  ##
  # Logic of +status+ command.
  #
  class StatusCommand
    def initialize(app)
      @talker = app.talker
      @index = app.client.index.clone
      @config = app.config
    end

    def on_new(filename, _)
      @talker.say("[NEW] #{filename}")
    end

    def on_backup(filename, _)
      @talker.say("[BACKUP] #{filename}")
    end

    def on_same(filename, entry)
      @talker.babble("[SAME] #{filename}")
      @index.delete(entry.public_id)
    end

    def on_changed(filename, entry)
      @talker.say("[CHANGED] #{filename}")
      @index.delete(entry.public_id)
    end

    def wrap_up
      @index.each_key do |id|
        @talker.say("[MISSING] #{@config.base_url}/entry/#{id}")
      end
    end
  end

  ##
  # Logic of +push+ command.
  #
  class PushCommand
    def initialize(app)
      @talker = app.talker
      @client = app.client
      @config = app.config
    end

    def on_new(filename, entry)
      @client.create(entry) do |id|
        Parser.inject_id(@params.target, filename, id)
        @talker.ok("#{filename} => #{@config.base_url}/entry/#{id}")
      end
    end

    def on_backup(filename, entry)
      update(filename, entry)
    end

    def on_same(filename, _)
      @talker.babble("[SAME] #{filename}")
    end

    def on_changed(filename, entry)
      update(filename, entry)
    end

    def update(filename, entry)
      @client.update(entry) do
        id = entry.public_id
        @talker.ok("#{filename} => #{@config.base_url}/entry/#{id}")
      end
    end

    def wrap_up
    end
  end

  ##
  # Main application's class.
  #
  class App
    attr_reader :config, :client, :talker

    def initialize(args = nil)
      @params = CmdArgs.parse(args)
      @config = Config.make(@params)
      @talker = Talker.new.tap { |x| x.verbose = @params.verbose }
      @client = HttpClient.new(@config)
    end

    def headless=(value)
      @talker.headless = value
    end

    def entry_status(entry)
      return :new if entry.new?
      sig = @client.index[entry.public_id]
      return :backup if sig.nil?
      return :same if sig == entry.md5
      :changed
    end

    def each_parsed
      FileSet.new(@params.files).each do |filename|
        begin
          entry = Parser.load(@params.target, filename)
          yield filename, entry if entry.publish?
        rescue Parser::ParseError => e
          talker.say("[ERROR] #{filename}\n    #{e.message}")
        end
      end
    end

    def handle_parsed_files(command)
      each_parsed do |filename, entry|
        status = entry_status(entry)
        method = "on_#{status}".to_sym
        unless command.class.method_defined?(method)
          raise "Bad status: #{status}"
        end
        command.send(method, filename, entry)
      end
      command.wrap_up
    end

    def perform_status
      handle_parsed_files(StatusCommand.new(self))
    end

    def perform_push
      handle_parsed_files(PushCommand.new(self))
    end

    def perform_help
      @talker.say(HELP_BANNER)
    end

    def run
      public_send("perform_#{@params.command}")
    end
  end

  ##
  # Main entrypoint.
  #
  def self.main
    App.new.run
  end
end
