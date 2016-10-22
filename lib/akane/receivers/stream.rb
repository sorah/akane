require 'akane/receivers/abstract_receiver'
require 'socket'
require 'twitter'

module Akane
  module Receivers
    class Stream < AbstractReceiver
      class TimeoutError < StandardError; end

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
          access_token_secret: @account[:secret],
          ssl_socket_class: CustomSSLSocketFactory.new(self),
        )
      end

      attr_reader :thread
      attr_accessor :last

      def start
        @logger.info "Stream : Starting"

        @last = Time.now
        @retry_count = 0
        @thread = Thread.new do
          begin
            stream.send(@stream_method, @stream_options) do |obj|
              @retry_count = 0

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
              else
                next
              end
            end
          rescue Exception => e
            raise e if defined?(Twitter::Streaming::MockClient)
            @logger.error 'Error on stream'
            @logger.error e.inspect
            @logger.error e.backtrace

            @retry_count += 1

            # reconnecting https://dev.twitter.com/streaming/overview/connecting
            case e
            when Twitter::Error::EnhanceYourCalm # 420
              interval = 5 ** @retry_count
            when Twitter::Error
              interval = [320, 5 ** @retry_count].min
            else
              interval = [16, 0.25 * @retry_count].min
            end

            @logger.info "stream will reconnect after #{interval} sec (retry_count=#{@retry_count})"
            sleep interval
            @logger.info 'stream reconnecting'
            retry
          end
        end

        @watchdog = Thread.new do
          th = @thread
          begin
            loop do
              break unless @thread
              # @logger.debug "watchdog last #{@last} #{Time.now - @last}"
              if (Time.now - @last) > 90
                @last = Time.now
                @logger.error 'watchdog timeout'
                th.raise(TimeoutError)
              end
              sleep 1
            end
            @logger.info 'watchdog stop'
          rescue Exception => e
            @logger.error 'Error on watchdog'
            @logger.error e.inspect
            @logger.error e.backtrace

            sleep 5
            @logger.info 'watchdog restarting'
            retry
          end
        end

        @thread.abort_on_exception = true

        self
      end

      def stop
        @thread.tap(&:kill).join
        @thread = nil
        self
      end

      class CustomSSLSocketFactory
        def initialize(target)
          @target = target
        end

        def new(*args)
          OpenSSL::SSL::SSLSocket.new(*args).tap do |sock|
            class << sock
              def last_target=(x)
                @akane_ext_last_target = x
              end
              def readpartial(*)
                super.tap do |x|
                  @akane_ext_last_target.last = Time.now
                end
              end
            end
            sock.last_target = @target
          end
        end
      end
    end
  end
end
