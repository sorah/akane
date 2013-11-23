module Akane
  module Receivers
    class AbstractReceiver
      def initialize(consumer: raise(ArgumentError, 'missing consumer'),
                     account:  raise(ArgumentError, 'missing account'),
                     logger: Logger.new($stdout),
                     config: {})
        @consumer = consumer
        @account = account
        @logger = logger
        @config = config

        @hooks = {}
      end

      def start
        raise NotImplementedError
      end

      def stop
        raise NotImplementedError
      end

      def running?
        raise NotImplementedError
      end

      def on(kind, &block)
        (@hooks[kind] ||= []) << block
        self
      end

      def on_tweet(&block) on(:tweet, &block) end
      def on_delete(&block) on(:delete, &block) end
      def on_message(&block) on(:message, &block) end
      def on_event(&block) on(:event, &block) end

      private

      def invoke(kind, *args)
        return unless @hooks[kind]
        @hooks[kind].each { |hook| hook.call(*args) }
        self
      end
    end
  end
end
