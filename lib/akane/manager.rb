require 'eventmachine'
require 'akane/config'
require 'akane/recorder'
require 'akane/receivers/stream'

module Akane
  class Manager
    def initialize(config)
      @config = config
    end

    def prepare
      @receivers = @config["accounts"].map do |name, credential|
        Akane::Receivers::Stream.new(
          consumer: {token: @config["consumer"]["token"], secret: @config["consumer"]["secret"]},
          account: {token: credential["token"], secret: credential["secret"]},
          logger: @config.logger
        ).tap do |receiver|
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
        require "akane/storages/#{kind}"
        Akane::Storages.const_get(kind.gsub(/(?:\A|_)(.)/) { $1.upcase }).new(
          config: config,
          logger: @config.logger
        )
      end

      @recorder = Akane::Recorder.new(@storages)
    end

    def start
      @receivers.each(&:start)
    end

    def run
      self.prepare()

      if EM.reactor_running?
        start()
      else
        EM.epoll
        EM.kqueue
        EM.run do
          start()
        end
      end
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
