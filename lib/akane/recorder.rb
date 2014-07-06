require 'thread'
require 'timeout'

module Akane
  class Recorder
    def initialize(storages, timeout: 20, logger: Logger.new(nil))
      @storages = storages
      @logger = logger
      @queue = Queue.new
      @recently_performed = RoundrobinFlags.new(1000)
      @timeout = timeout
    end

    def queue_length
      @queue.size
    end

    def record_tweet(account, tweet)
      @queue << [:record_tweet, account, tweet]
      self
    end

    def mark_as_deleted(account, user_id, tweet_id)
      @queue << [:mark_as_deleted, account, user_id, tweet_id]
      self
    end

    def record_message(account, message)
      @queue << [:record_message, account, message]
      self
    end

    def record_event(account, event)
      @queue << [:record_event, account, event]
      self
    end

    def dequeue(raise_errors = false)
      perform(*@queue.pop, raise_errors: raise_errors)
    end

    def perform(action, account, *payload, raise_errors: false)
      if action == :record_tweet
        return if @recently_performed[payload.last[:id]]
        @recently_performed.flag!(payload.last[:id])

        # WTF: Twitter::NullObject
        unless payload.last[:retweeted_status].nil?
          perform(:record_tweet, account, payload.last[:retweeted_status], raise_errors: raise_errors)
        end
      end

      @storages.each do |storage|
        begin
          timeout(@timeout) do
            storage.__send__(action, account, *payload)
          end

        rescue Timeout::Error => e
          raise e if raise_errors
          @logger.warn "#{storage} (#{action}) timed out"

        rescue Exception => e
          raise e if e === Interrupt
          raise e if raise_errors
          @logger.error "Error while recorder performing to #{storage.inspect}:  #{e.inspect}"
          @logger.error e.backtrace
        end
      end
    end

    def run(raise_errors = false)
      loop do
        begin
          self.dequeue(raise_errors)
        rescue Exception => e
          raise e if Interrupt === e
          raise e if raise_errors
          @logger.error "Error while recorder dequing: #{e.inspect}"
          @logger.error e.backtrace
        end
      end
    end

    class RoundrobinFlags
      def initialize(size)
        @hash = {}
        @limit_size = size
      end

      def [](k)
        @hash[k]
      end

      def flag!(k)
        @hash[k] = true
        if @limit_size < @hash.size
          @hash.keys.first(@hash.size-@limit_size).each do |overflowed_key|
            @hash.delete overflowed_key
          end
        end
        nil
      end

      def unflag!(k)
        @hash.delete k
      end

      def flags
        @hash.keys
      end
    end
  end
end
