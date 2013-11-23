require 'akane/storages/abstract_storage'
require 'date'
require 'json'
require 'time'
require 'pathname'

module Akane
  module Storages
    class File < AbstractStorage
      def initialize(*)
        super
        @screen_name_to_id_cache = {}
        @dir = Pathname.new(@config["dir"])
        [@dir, @dir.join('users'), @dir.join('event'), @dir.join('timeline')].each do |d|
          d.mkdir unless d.exist?
        end
      end

      def record_tweet(account, tweet)
        timeline_io.puts "[#{tweet["created_at"].xmlschema}][#{account}] #{tweet["user"]["screen_name"]}: " \
                         "#{tweet["text"].gsub(/\r?\n/,' ')} (#{tweet["user"]["id"]},#{tweet["id"]})"

        tweets_io_for_user(tweet["user"]["id"], tweet["user"]["screen_name"]) do |io|
          io.puts tweet.attrs.to_json
        end
      end

      def mark_as_deleted(account, user_id, tweet_id)
        timeline_deletion_io.puts "#{Time.now.xmlschema},#{user_id},#{tweet_id}"
        tweets_deletion_io_for_user(user_id) do |io|
          io.puts "#{Time.now.xmlschema},#{user_id},#{tweet_id}"
        end
      end

      def record_event(account, event)
        event_io.puts event.merge("happened_on" => account).to_json
      end

      def record_message(account, message)
        messages_raw_io_for_user(message["sender"]["id"], message["sender"]["screen_name"]) do |io|
          io.puts message.to_json
        end
        messages_io_for_user(message["sender"]["id"], message["sender"]["screen_name"]) do |io|
          io.puts "[#{message["created_at"].xmlschema}] #{message["sender"]["screen_name"]} -> #{message["recipient"]["screen_name"]}:" \
                           " #{message["text"]} (#{message["sender"]["id"]} -> #{message["recipient"]["id"]},#{message["id"]})"
        end
      end

      private

      def timeline_io
        if @timeline_io_date != Date.today || !@timeline_io
          date = @timeline_io_date = Date.today
          @timeline_io = ::File.open(@dir.join('timeline', date.strftime('%Y-%m-%d.txt')), 'a')
          @timeline_io.sync = !@config.key?("sync_io") || @config["sync_io"]
          @timeline_io
        else
          @timeline_io
        end
      end

      def timeline_deletion_io
        if @timeline_deletion_io_date != Date.today || !@timeline_deletion_io
          date = @timeline_deletion_io_date = Date.today
          @timeline_deletion_io = ::File.open(@dir.join('timeline', date.strftime('%Y-%m-%d.deleted.txt')), 'a')
          @timeline_deletion_io.sync = !@config.key?("sync_io") || @config["sync_io"]
          @timeline_deletion_io
        else
          @timeline_deletion_io
        end
      end

      def event_io
        if @event_io_date != Date.today || !@event_io
          date = @event_io_date = Date.today
          @event_io = ::File.open(@dir.join('event', date.strftime('%Y-%m-%d.txt')), 'a')
          @event_io.sync = !@config.key?("sync_io") || @config["sync_io"]
          @event_io
        else
          @event_io
        end
      end

      def tweets_io_for_user(user_id, screen_name=nil, &block)
        symlink_user_dir(user_id, screen_name)
        date = Date.today
        ::File.open(@dir.join('users', user_id.to_s, date.strftime('tweets.%Y-%m-%d.txt')), 'a', &block)
      end

      def tweets_deletion_io_for_user(user_id, screen_name=nil, &block)
        symlink_user_dir(user_id, screen_name)
        date = Date.today
        ::File.open(@dir.join('users', user_id.to_s, date.strftime('tweets.%Y-%m-%d.deleted.txt')), 'a', &block)
      end

      def messages_io_for_user(user_id, screen_name=nil, &block)
        symlink_user_dir(user_id, screen_name)
        date = Date.today
        ::File.open(@dir.join('users', user_id.to_s, date.strftime('messages.%Y-%m-%d.txt')), 'a', &block)
      end

      def messages_raw_io_for_user(user_id, screen_name=nil, &block)
        symlink_user_dir(user_id, screen_name)
        date = Date.today
        ::File.open(@dir.join('users', user_id.to_s, date.strftime('messages.%Y-%m-%d.raw.txt')), 'a', &block)
      end


      def symlink_user_dir(user_id, screen_name=nil)
        user_id_dir = @dir.join('users', user_id.to_s)
        user_id_dir.mkdir unless user_id_dir.exist?

        return unless screen_name
        screen_name_dir = @dir.join('users', screen_name)

        unless @screen_name_to_id_cache.has_key?(screen_name)
          @screen_name_to_id_cache[screen_name] = if screen_name_dir.symlink?
                                                    screen_name_dir.realpath.basename.to_s
                                                  else
                                                    nil
                                                  end
          @logger.debug "Caching dir for #{screen_name} : #{@screen_name_to_id_cache[screen_name].inspect}"
        end

        cached_id = @screen_name_to_id_cache[screen_name]

        if cached_id && cached_id != user_id.to_s
          prev_id = screen_name_dir.realpath.basename
          @logger.info "Renaming #{screen_name}(#{prev_id}) dir: #{screen_name} -> #{prev_id}-#{screen_name}"
          screen_name_dir.rename(@dir.join('users',"#{prev_id}-#{screen_name}"))
          screen_name_dir.make_symlink(user_id_dir.basename)
          @screen_name_to_id_cache[screen_name] = user_id.to_s

        elsif cached_id.nil?
          @logger.info "Linking #{screen_name}->#{user_id} dir"
          screen_name_dir.make_symlink(user_id_dir.basename)
          @screen_name_to_id_cache[screen_name] = user_id.to_s
        end
      end
    end
  end
end
