require 'twitter'
require 'thread'

class Twitter::Streaming::MockClient
  Original = Twitter::Streaming::Client

  class << self
    def clients
      @clients ||= []
    end

    def clients_mutex
      @clients_mutex ||= Mutex.new
    end

    def add_client(client)
      clients_mutex.synchronize {
        clients << client
      }
    end

    def remove_client(client)
      clients_mutex.synchronize {
        clients.delete client
      }
    end

    def invoke(*args)
      clients.each do |client|
        client.invoke(*args)
      end

      self
    end

    def enable!
      klass = self
      Twitter::Streaming.instance_eval {
        remove_const :Client
        const_set :Client, klass
      }
    end

    def disable!
      klass = Original
      Twitter::Streaming.instance_eval {
        remove_const :Client
        const_set :Client, klass
      }
    end
  end

  def initialize(options={})
    @options = options
    @queues = []
    @mutex = Mutex.new
  end

  attr_accessor :options, :hooks

  def invoke(*args)
    @queues.each do |queue|
      queue << args
    end
  end

  def user(options = {}, &block)
    connect(&block)
  end

  private

  def connect
    queue = Queue.new
    was_empty = nil
    @mutex.synchronize {
      was_empty = @queues.empty?
      @queues << queue

      if was_empty
        self.class.add_client self
      end
    }
    while _ = queue.pop
      break if _ == [:disconnect]
      yield *_
    end
  ensure
    @mutex.synchronize {
      @queues.delete queue
      if @queues.empty?
        self.class.remove_client self
      end
    }
  end
end

Twitter::Streaming::MockClient.enable!
