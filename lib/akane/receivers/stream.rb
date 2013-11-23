require 'akane/receivers/abstract_receiver'
require 'tweetstream'


module Akane
  module Receivers
    class Stream < AbstractReceiver
      def initialize(*)
        super
        @running = false
      end

      def running?() @running end

      def stream
        @stream ||= TweetStream::Client.new(
          auth_method: :oauth,
          consumer_key: @consumer[:token],
          consumer_secret: @consumer[:secret],
          oauth_token: @account[:token],
          oauth_token_secret: @account[:secret]
        ).tap { |stream|
          stream.on_anything do |hash|
            invoke(:event, hash) if hash["event"]
          end

          stream.on_timeline_status do |tweet|
            invoke(:tweet, tweet)
          end

          stream.on_delete do |user_id, tweet_id|
            invoke(:delete, user_id, tweet_id)
          end

          stream.on_direct_message do |message|
            invoke(:message, message)
          end
        }
      end

      def start
        @logger.info "Stream : Starting"
        stream.userstream
        @running = true
        self
      end

      def stop
        stream.stop_stream
        @stream = nil
        @running = false
        self
      end
    end
  end
end
