require 'akane/storages/abstract_storage'
require 'elasticsearch'

module Akane
  module Storages
    class Elasticsearch < AbstractStorage
      def initialize(*)
        super

        @es = ::Elasticsearch::Client.new(
          hosts: [@config["host"]],
          logger: @config["enable_es_log"] ? @logger : nil
        )
        @index_name = @config["index"] || 'akane'
        set_elasticsearch_up
      end

      def record_tweet(account, tweet)
        tweet_hash = tweet.attrs
        tweet_hash['deleted'] = false
        @es.index(index: @index_name, type: 'tweet', id: tweet_hash['id_str'], body: tweet_hash)
      end

      def mark_as_deleted(account, user_id, tweet_id)
        @es.update(index: @index_name, type: 'tweet', ignore: 404,
                   id: tweet_id.to_s, body: {doc: {deleted: true}})
      end

      def record_event(account, event)
        case event["event"]
        when 'favorite'
        when 'unfavorite'
        when 'block'
        when 'unblock'
        when 'follow'
        when 'unfollow'
        end
      end

      def record_message(account, message)
        @es.index(index: @index_name, type: 'message', id: message['id_str'], body: message.attrs)
      end

      private

      def set_elasticsearch_up
        begin
          @es.indices.get_mapping(index: @index_name)
        rescue ::Elasticsearch::Transport::Transport::Errors::NotFound => e
          raise e unless /IndexMissingException/ === e.message

          @logger.info 'elasticsearch.setup: creating index'

          date_format = "EE MMM d HH:mm:ss Z yyyy"
          user_properties = {
                      notifications: {type: 'boolean', store: 'no', index: 'no'},
                      follow_request_sent: {type: 'boolean', store: 'no', index: 'no'},
                      following: {type: 'boolean', store: 'no', index: 'no'},
                      default_profile_image: {type: 'boolean', store: 'no', index: 'no'},
                      default_profile: {type: 'boolean', store: 'no', index: 'no'},
                      geo_enabled: {type: 'boolean', store: 'no', index: 'no'},
                      time_zone: {type: 'string', index: 'not_analyzed'},
                      utc_offset: {type: 'integer', store: 'yes', index: 'no'},
                      favourites_count: {type: 'integer', store: 'no', index: 'no'},
                      created_at: {type: 'date', format: date_format, store: 'yes', index: 'no'},
                      listed_count: {type: 'integer', store: 'no', index: 'no'},
                      friends_count: {type: 'integer', store: 'no', index: 'no'},
                      followers_count: {type: 'integer', store: 'no', index: 'no'},
                      id: {type: 'long'},
                      id_str: {type: 'string', index: 'not_analyzed'},
                      name: {type: 'string'}.merge(
                        @config["kuromoji"] ? {analyzer: 'kuromoji'} : {}),
                      screen_name: {type: 'string', index: 'not_analyzed'},
                      location: {type: 'string', index: 'no'},
                      url: {type: 'string', index: 'not_analyzed'},
                      description: {type: 'string'}.merge(
                        @config["kuromoji"] ? {analyzer: 'kuromoji'} : {}),
                      protected: {type: 'boolean'},
                      verified: {type: 'boolean'},
                      statuses_count: {type: 'long', store: 'yes', index: 'no'},
                      lang: {type: 'string', index: 'not_analyzed'},
                      contributors_enabled: {type: 'boolean'},
                      is_translator: {type: 'boolean'},
                      profile_background_color: {type: 'string', store: 'no', index: 'no'},
                      profile_background_image_url: {type: 'string', store: 'no', index: 'no'},
                      profile_background_image_url_https: {type: 'string', store: 'no', index: 'no'},
                      profile_background_tile: {type: 'boolean', store: 'no', index: 'no'},
                      profile_image_url: {type: 'string', type: 'string', index: 'no'},
                      profile_image_url_https: {type: 'string', index: 'no'},
                      profile_link_color: {type: 'string', store: 'no', index: 'no'},
                      profile_sidebar_border_color: {type: 'string', store: 'no', index: 'no'},
                      profile_sidebar_fill_color: {type: 'string', store: 'no', index: 'no'},
                      profile_use_background_image: {type: 'boolean', store: 'no', index: 'no'},
                    }

          minimum_user_properties = Hash[
            user_properties.map { |k, v|
              [k, %i(id id_str screen_name).include?(k) ? v : {type: v[:type], format: v[:format], store: 'no', index: 'no'}] }
          ]

          tweet_properties = {
                  lang: {type: 'string', index: 'not_analyzed'},
                  deleted: {type: 'boolean', null_value: false},
                  filter_level: {type: 'string'},
                  retweeted: {type: 'boolean', store: 'no', index: 'no'},
                  favorited: {type: 'boolean', store: 'no', index: 'no'},
                  entities: {type: 'boolean', store: 'no', index: 'no'},
                  favorite_count: {type: 'integer', store: 'no', index: 'no'},
                  retweet_count: {type: 'integer', store: 'no', index: 'no'},
                  in_reply_to_status_id_str: {type: 'string', index: 'not_analyzed'},
                  in_reply_to_status_id: {type: 'long'},
                  truncated: {type: 'boolean', store: 'no', index: 'no'},
                  source: {type: 'string'},
                  text: {type: 'string', boost: 2.0, }.merge(
                    @config["kuromoji"] ? {analyzer: 'kuromoji'} : {}),
                  id_str: {type: 'string', index: 'not_analyzed'},
                  id: {type: 'long'},
                  created_at: {type: 'date', format: date_format},
                  in_reply_to_user_id_str: {type: 'string', index: 'not_analyzed'},
                  in_reply_to_user_id: {type: 'long'},
                  user: {
                    type: 'object',
                    properties: user_properties,
                  },
                  coordinates: {
                    type: 'object',
                    properties: {
                      coordinates: {type: 'geo_point'},
                      type: {type: 'string', index: 'not_analyzed'},
                    },
                  },
                  place: {
                    type: 'object',
                    properties: {
                      attributes: {type: 'object', store: 'no', index: 'no'},
                      bounding_box: {type: 'object', index: 'no'},
                      country: {type: 'string', index: 'not_analyzed'},
                      country_code: {type: 'string', index: 'not_analyzed'},
                      id: {type: 'string', index: 'not_analyzed'},
                      name: {type: 'string'},
                      place_type: {type: 'string', index: 'not_analyzed'},
                      url: {type: 'string', index: 'no', store: 'yes'},
                    },
                  },
                  contributors: {type: 'object', store: 'no', index: 'no'},
                }

          minimum_tweet_properties = Hash[
            tweet_properties.map { |k, v|
              if k == :user
                [k, {type: 'object', properties: minimum_user_properties}]
              else
                [k, %i(id id_str text).include?(k) ? v : {type: v[:type], format: v[:format], store: 'no', index: 'no'}]
              end
            }
          ]
          tweet_properties[:retweeted_status] = {type: 'object', properties: minimum_tweet_properties}
          minimum_tweet_properties[:retweeted_status] = {type: 'object', store: 'no', index: 'no'}

          @es.indices.create(index: @index_name, body: {
            settings: {
            },
            analysis: {
              standard: {
                  type: 'standard'
              },
            }.merge( @config["kuromoji"] ?
                {kuromoji: {
                  type: "kuromoji_tokenizer",
                  mode: "search",
                }} : {}
              ),
            mappings: {
              tweet: {
                _source: {enabled: true},
                properties: tweet_properties,
              },
              message: {
                _source: {enabled: true},
                properties: {
                  created_at: {type: 'date', format: date_format, store: 'yes', index: 'no'},
                  text: {type: 'string', boost: 2.0, store: 'yes', }.merge(
                    @config["kuromoji"] ? {analyzer: 'kuromoji'} : {}),
                  sender_id_str: {type: 'string', store: 'yes', index: 'not_analyzed'},
                  sender_screen_name: {type: 'string', store: 'yes', index: 'not_analyzed'},
                  sender_id: {type: 'long', store: 'yes', },
                  recipient_id_str: {type: 'string', store: 'yes', index: 'not_analyzed'},
                  recipient_id: {type: 'long', store: 'yes', },
                  recipient_screen_name: {type: 'string', store: 'yes', index: 'not_analyzed'},
                  sender: {type: 'object', store: 'yes', properties: minimum_user_properties},
                  recipient: {type: 'object', store: 'yes', properties: minimum_user_properties},
                },
              },
              event_favorite: {
                _source: {enabled: true},
                properties: {
                  created_at: {type: 'date', format: date_format, store: 'yes', index: 'no'},
                  event: {type: 'string', store: 'yes', index: 'not_analyzed'},
                  source: {type: 'object', store: 'yes', properties: minimum_user_properties},
                  target: {type: 'object', store: 'yes', properties: minimum_user_properties},
                  target_object: {type: 'object', store: 'yes', properties: minimum_tweet_properties},
                },
              },
              event_user_interaction: {
                _source: {enabled: true},
                properties: {
                  created_at: {type: 'date', format: date_format, store: 'yes', index: 'no'},
                  event: {type: 'string', store: 'yes', index: 'not_analyzed'},
                  source: {type: 'object', store: 'yes', properties: minimum_user_properties},
                  target: {type: 'object', store: 'yes', properties: minimum_user_properties},
                },
              },
            },
          })
        end
      end
    end
  end
end
