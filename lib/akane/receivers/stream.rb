require 'akane/receivers/abstract_receiver'
require 'twitter'

module Akane
  module Receivers
    class Stream < AbstractReceiver
      def initialize(*)
        super
        @thread = nil

        if @config["method"]
          @stream_method = @config["method"].to_sym
        else
          @stream_method = :user
        end

        if @config["options"]
          @stream_options = Hash[@config["options"].map do |k,v|
            [k.to_sym, v]
          end]
        else
          @stream_options = {}
        end
      end

      def name
        # For backward compatibility, user stream returns only account name if
        # config.name not specified.
        @name ||= @config['name'] || @account[:name]
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
          begin
            stream.send(@stream_method, @stream_options) do |obj|
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
          rescue Exception => e
            raise e if defined?(Twitter::Streaming::MockClient)
            @logger.error 'Error on stream'
            @logger.error e.inspect
            @logger.error e.backtrace
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
