require 'akane/config'
require 'akane/recorder'
require 'akane/receivers/stream'

module Akane
  class Manager
    def initialize(config)
      @config = config
      @logger = config.logger
    end

    def prepare
      @logger.info 'Preparing'
      @receivers = @config["accounts"].map do |name, credential|
        Akane::Receivers::Stream.new(
          consumer: {token: @config["consumer"]["token"], secret: @config["consumer"]["secret"]},
          account: {token: credential["token"], secret: credential["secret"]},
          logger: @config.logger
        ).tap do |receiver|
          @logger.info "Preparing... receiver - #{receiver.class}"
          receiver.on_tweet(  &(method(:on_tweet).to_proc.curry[name]))
          receiver.on_message(&(method(:on_message).to_proc.curry[name]))
          receiver.on_event(  &(method(:on_event).to_proc.curry[name]))
          receiver.on_delete( &(method(:on_delete).to_proc.curry[name]))
        end
      end

      @storages = @config["storages"].flat_map do |definition|
        case definition
        when Hash
          definition.map do |kind, config|
            [kind, config]
          end
        when String
          [[definition, {}]]
        end
      end.map do |kind, config|
        @logger.info "Preparing... storgae - #{kind}"
        require "akane/storages/#{kind}"
        Akane::Storages.const_get(kind.gsub(/(?:\A|_)(.)/) { $1.upcase }).new(
          config: config,
          logger: @config.logger
        )
      end

      @recorder = Akane::Recorder.new(@storages, logger: @config.logger)

      @logger.info "Prepared with #{@storages.size} storage(s) and #{@receivers.size} receiver(s)"
    end

    def start
      @logger.info "Starting receivers..."
      @receivers.each(&:start)
      @logger.info "Starting recorder..."
      @recorder.run
    end

    def run
      @logger.info "Running..."
      self.prepare()

      start()
    end

    private

    def on_tweet(account, tweet)
      @recorder.record_tweet(account, tweet)
    end

    def on_message(account, message)
      @recorder.record_message(account, message)
    end

    def on_event(account, event)
      @recorder.record_event(account, event)
    end

    def on_delete(account, user_id, tweet_id)
      @recorder.mark_as_deleted(account, user_id, tweet_id)
    end
  end
end
