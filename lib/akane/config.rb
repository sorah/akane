require 'yaml'
require 'logger'
require 'oauth'

module Akane
  class Config
    def initialize(file_or_hash)
      @hash = case file_or_hash
              when String
                YAML.load_file(file_or_hash)
              when Hash
                file_or_hash
              else
                raise ArgumentError, 'file_or_hash is not Hash or String'
              end
    end

    def [](k)
      @hash[k.to_s]
    end

    def consumer
      consumer = self[:consumer]
      return nil unless consumer
      OAuth::Consumer.new(consumer['token'], consumer['secret'],
                          site: 'https://api.twitter.com/')
    end

    def logger
      Logger.new(@hash["log"] || $stdout)
    end

    def log_direct(line)
      if @hash["log"]
        open(@hash["log"], 'a') do |io|
          io.puts line
        end
      else
        $stdout.puts line
      end
    end
  end
end
