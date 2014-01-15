require 'akane/receivers/abstract_receiver'
require 'twitter'

module Akane
  module Receivers
    class Stream < AbstractReceiver
      def initialize(*)
        super
        @thread = nil
      end

      def running?() !!(@thread && @thread.alive?) end

      def stream
        @stream ||= Twitter::Streaming::Client.new(
          consumer_key: @consumer[:token],
          consumer_secret: @consumer[:secret],
          access_token: @account[:token],
          access_token_secret: @account[:secret]
        )
      end

      attr_reader :thread

      def start
        @logger.info "Stream : Starting"

        @thread = Thread.new do
          stream.user do |obj|
            case obj
            when Twitter::Tweet
              invoke(:tweet, obj)
            when Twitter::DirectMessage
              invoke(:message, obj)
            when Twitter::Streaming::DeletedTweet
              invoke(:delete, obj.user_id, obj.id)
            when Twitter::Streaming::Event
              invoke(:event,
                     'event' => obj.name, 'source' => obj.source,
                     'target' => obj.target, 'target_object' => obj.target_object)
            end
          end
        end

        self
      end

      def stop
        @thread.tap(&:kill).join
        @thread = nil
        self
      end
    end
  end
end
