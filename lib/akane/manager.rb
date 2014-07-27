require 'akane/config'
require 'akane/recorder'
require 'akane/receivers/stream'

module Akane
  class Manager
    def initialize(config)
      @config = config
      @logger = config.logger
    end

    def prepare
      @logger.info 'Preparing'
      @receivers = @config["accounts"].flat_map do |name, credential|
        receiver_definitions = credential["receivers"] || ['stream']

        receiver_definitions.map do |definition|
          if definition.kind_of?(Hash)
            if 1 < definition.size
              @logger.warn "Only 1 receiver definition is used in one Hash instance."
            end

            kind, config = definition.each.first
          else
            kind, config = definition, {}
          end

          class_name = kind.gsub(/(?:\A|_)(.)/) { $1.upcase }

          retried = false
          begin
            receiver_class = Akane::Receivers.const_get(class_name)
          rescue NameError => e
            raise e if retried
            retried = true
            require "akane/receivers/#{kind}"
            retry
          end

          receiver_class.new(
            consumer: {token: @config["consumer"]["token"], secret: @config["consumer"]["secret"]},
            account: {token: credential["token"], secret: credential["secret"], name: name},
            config: config,
            logger: @config.logger
          ).tap do |receiver|
            @logger.info "Preparing... receiver - #{receiver.class}"
            receiver.on_tweet(&(  method(:on_tweet).to_proc.curry[receiver.name]))
            receiver.on_message(&(method(:on_message).to_proc.curry[receiver.name]))
            receiver.on_event(&(  method(:on_event).to_proc.curry[receiver.name]))
            receiver.on_delete(&( method(:on_delete).to_proc.curry[receiver.name]))
          end
        end
      end

      @storages = @config["storages"].flat_map do |definition|
        case definition
        when Hash
          definition.map do |kind, config|
            [kind, config]
          end
        when String
          [[definition, {}]]
        end
      end.map do |kind, config|
        @logger.info "Preparing... storage - #{kind}"
        require "akane/storages/#{kind}"
        Akane::Storages.const_get(kind.gsub(/(?:\A|_)(.)/) { $1.upcase }).new(
          config: config,
          logger: @config.logger
        )
      end

      @recorder = Akane::Recorder.new(
        @storages,
        timeout: @config["timeout"] || 20,
        logger: @config.logger
      )

      @logger.info "Prepared with #{@storages.size} storage(s) and #{@receivers.size} receiver(s)"
    end

    def start
      @logger.info "Starting receivers..."
      @receivers.each(&:start)

      @logger.info "Assigning signal handlers..."
      handle_signals

      @logger.info "Starting recorder..."
      @recorder.run

      @logger.info "Recorder stopped. Waiting for storages..."
      stop_storages
    end

    def handle_signals
      @terminating = false

      begin
        require 'sigdump/setup'
      rescue LoadError
      end

      on_interrupt = proc do
        if @terminating
          @config.log_direct "Terminating forcely..."
          exit
        else
          @terminating = true
          @config.log_direct "Gracefully stopping..."
          @recorder.stop!
        end
      end

      trap(:INT, on_interrupt)
      trap(:TERM, on_interrupt)
    end

    def run
      @logger.info "Running..."
      self.prepare()

      start()
    end

    def stop_storages
      @storages.each(&:stop!)
      loop do
        not_exitable = @storages.any? do |storage|
          if storage.exitable?
            false
          else
            @logger.debug "[status] #{storage.name}: #{storage.status || 'not exitable'.freeze}"
            true
          end
        end
        break unless not_exitable
        sleep 1
      end
    end

    private

    def on_tweet(account, tweet)
      @recorder.record_tweet(account, tweet)
    end

    def on_message(account, message)
      @recorder.record_message(account, message)
    end

    def on_event(account, event)
      @recorder.record_event(account, event)
    end

    def on_delete(account, user_id, tweet_id)
      @recorder.mark_as_deleted(account, user_id, tweet_id)
    end
  end
end
