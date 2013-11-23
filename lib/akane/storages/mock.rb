require 'akane/storages/abstract_storage'

module Akane
  module Storages
    class Mock < AbstractStorage
      class << self
        def recorded_tweets
          @recorded_tweets ||= []
        end

        def deletion_marks
          @deletion_marks ||= []
        end

        def recorded_events
          @recorded_events ||= []
        end

        def recorded_messages
          @recorded_messages ||= []
        end

        def reset!
          [recorded_tweets, deletion_marks,
            recorded_events, recorded_messages].each(&:clear)
          self
        end
      end

      def record_tweet(account, tweet)
        self.class.recorded_tweets << [account, tweet]
        self
      end

      def mark_as_deleted(account, user_id, tweet_id)
        self.class.deletion_marks << [account, user_id, tweet_id]
        self
      end

      def record_event(account, event)
        self.class.recorded_events << [account, event]
        self
      end

      def record_message(account, message)
        self.class.recorded_messages << [account, message]
        self
      end
    end
  end
end
