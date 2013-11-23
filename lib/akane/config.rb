require 'yaml'
require 'logger'

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

    def logger
      Logger.new(@hash["log"] || $stdout)
    end
  end
end
