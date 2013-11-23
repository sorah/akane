require 'akane/manager'
require 'akane/config'

module Akane
  class CLI
    class << self
      def run(*args)
        self.new(*args).run
      end
    end

    def initialize(args)
      @args = args
      @options = nil
    end

    def start
      config.logger.info 'Starting...'
      manager = Akane::Manager.new(config)
      manager.run
    end

    def help
      puts <<-EOH
Usage:
  akane COMMAND [ARGS]

Common commands:

  akane start        - start akari

Common options:

  -c, --config=FILE  - Specify config file name to use

      EOH
      0
    end

    def run
      if @args.include?('--help')
        @command = :help
      else
        @command = (@args.shift || :help).to_sym
      end

      result = if self.respond_to?(@command)
                 self.__send__(@command)
               else
                 self.help
               end

      result.kind_of?(Numeric) ? result : 0
    end

    private

    def config
      @config ||= Akane::Config.new(options[:config])
    end

    def option_parser
      @option_parser ||= OptionParser.new.tap do |opt|
        opt.on_tail('--help', 'Show this message') { help; exit 0 }
        opt.on_tail('-c CONF', '--config=CONF', 'Specify configuration file (default: ./akane.yml)') do |conf|
          @options[:config] = conf
        end
      end
    end

    def parse_options
      return @options if @options
      @options = {config: './akane.yml'}
      yield option_parser if block_given?
      option_parser.parse!(@args)
    end

    def options
      parse_options unless @options
      @options
    end
  end
end
