module Akane
  module Storages
    class AbstractStorage
      def initialize(config: raise(ArgumentError, 'missing config'), logger: Logger.new($stdout))
        @config = config
        @logger = logger
        @stop = false
      end

      def name
        self.class.name
      end

      def record_tweet(account, tweet)
        raise NotImplementedError
      end

      def mark_as_deleted(account, user_id, tweet_id)
        raise NotImplementedError
      end

      def record_event(account, event)
        raise NotImplementedError
      end

      def record_message(account, message)
        raise NotImplementedError
      end

      def stop!
        @stop = true
      end

      def exitable?
        true
      end

      def status
        nil
      end
    end
  end
end
