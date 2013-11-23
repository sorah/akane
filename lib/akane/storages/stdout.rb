require 'akane/storages/abstract_storage'

module Akane
  module Storages
    class Stdout < AbstractStorage
      def record_tweet(account, tweet)
        $stdout.puts "[#{account}] #{tweet["user"]["screen_name"]}: #{tweet["text"]}"
      end

      def mark_as_deleted(account, user_id, tweet_id)
        $stdout.puts "[#{account}](DELETION) #{user_id}/#{tweet_id}"
      end

      def record_event(account, event)
        $stdout.puts "[#{account}](EVENT) #{event["event"]}: #{event["source"]["screen_name"]}-> #{event["target"]["screen_name"]}"
      end

      def record_message(account, message)
        $stdout.puts "[#{account}](DM) #{message["user"]["screen_name"]}: #{message["text"]}"
      end
    end
  end
end
