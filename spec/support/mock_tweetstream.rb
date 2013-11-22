require 'tweetstream'


class TweetStream::MockClient
  Original = TweetStream::Client

  class << self
    def clients
      @clients ||= []
    end

    def invoke(event, *args)
      @clients.each do |client|
        client.invoke(event, *args)
      end

      self
    end

    def enable!
      klass = self
      TweetStream.instance_eval {
        remove_const :Client
        const_set :Client, klass
      }
    end

    def disable!
      klass = Original
      TweetStream.instance_eval {
        remove_const :Client
        const_set :Client, klass
      }
    end
  end

  def initialize(options={})
    @options = options
    @hooks = {}
  end

  attr_accessor :options, :hooks

  def on_anything(&block)         on('anything',        &block) end

  def on_event(event, &block)     on(event,              &block) end

  def on_timeline_status(&block)  on('timeline_status',  &block) end
  def on_delete(&block)           on('delete',           &block) end

  def on_direct_message(&block)   on('direct_message',   &block) end

  def on_limit(&block)            on('limit',            &block) end
  def on_error(&block)            on('error',            &block) end
  def on_unauthorized(&block)     on('unauthorized',     &block) end

  def on_inited(&block)           on('inited',           &block) end
  def on_reconnect(&block)        on('reconnect',        &block) end

  def on(event, &block)
    @hooks[event.to_s] = block
    self
  end

  def invoke(event, *args)
    @hooks[event.to_s].call *args
  end

  def connected?
    @connected
  end

  def userstream
    @connected = true
    self.class.clients << self
    self
  end

  def stop_stream
    self.class.clients.delete(self)
    @connected = false
    self
  end
end

TweetStream::MockClient.enable!
