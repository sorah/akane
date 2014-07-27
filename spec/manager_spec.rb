require 'spec_helper'
require 'akane/manager'
require 'akane/receivers/stream'
require 'akane/receivers/abstract_receiver'
require 'akane/storages/mock'
require 'akane/config'

describe Akane::Manager do
  let(:conf_accounts) do
    {
      "a" => {"token" => "a-access-token", "secret" => "a-access-secret"},
    }
  end
  let(:conf_storages) do
    [
      { "mock" => {"a" => "b"} }
    ]
  end

  let(:config) do
    Akane::Config.new(
      "consumer" => {
        "token" => "consumer-token", "secret" => "consumer-secret"
      },
      "accounts" => conf_accounts,
      "storages" => conf_storages,
      "timeout" => 72,
    ).tap { |_| _.stub(logger: Logger.new(nil)) }
  end

  subject { Akane::Manager.new(config) }

  # receivers -> manager -> recorder -> storage

  describe "#prepare" do
    it "creates receivers" do
      Akane::Receivers::Stream.should_receive(:new) \
        .with(consumer: {token: 'consumer-token', secret: 'consumer-secret'},
              account:  {token: 'a-access-token', secret: 'a-access-secret', name: 'a'},
              config: {},
              logger: config.logger) \
        .and_return(double("a").as_null_object)

      subject.prepare
    end

    it "instantiates storages" do
      Akane::Storages::Mock.should_receive(:new).with(config: {"a" => "b"}, logger: config.logger)
      subject.prepare
    end

    it "creates recorder with storages" do
      storage = double("storage")
      Akane::Storages::Mock.stub(new: storage)
      Akane::Recorder.should_receive(:new).with([storage], timeout: 72, logger: config.logger).and_call_original

      subject.prepare
    end

    context "with config.accounts[].receivers" do
      let(:conf_accounts) do
        {
          "a" => {
            "token" => "a-access-token",
            "secret" => "a-access-secret",
            "receivers" => [
              'foo',
              {"bar" => {'hello' => 'hola',}},
            ],
          },
          "b" => {
            "token" => "b-access-token",
            "secret" => "b-access-secret",
          },
        }
      end

      let(:foo_receiver) { Class.new(Akane::Receivers::AbstractReceiver) {} }
      let(:bar_receiver) { Class.new(Akane::Receivers::AbstractReceiver) {} }

      before do
        stub_const 'Akane::Receivers::Foo', foo_receiver
        stub_const 'Akane::Receivers::Bar', bar_receiver
      end

      it "creates receivers" do
        expect(foo_receiver).to receive(:new) \
          .with(consumer: {token: 'consumer-token', secret: 'consumer-secret'},
                account:  {token: 'a-access-token', secret: 'a-access-secret', name: 'a'},
                config: {},
                logger: config.logger) \
          .and_return(double("foo").as_null_object)

        expect(bar_receiver).to receive(:new) \
          .with(consumer: {token: 'consumer-token', secret: 'consumer-secret'},
                account:  {token: 'a-access-token', secret: 'a-access-secret', name: 'a'},
                config: {'hello' => 'hola',},
                logger: config.logger) \
          .and_return(double("bar").as_null_object)

        Akane::Receivers::Stream.should_receive(:new) \
          .with(consumer: {token: 'consumer-token', secret: 'consumer-secret'},
                account:  {token: 'b-access-token', secret: 'b-access-secret', name: 'b'},
                config: {},
                logger: config.logger) \
          .and_return(double("bstream").as_null_object)

        subject.prepare
      end
    end
  end

  describe "#start" do
    let(:receiver) { double("a").as_null_object }
    let(:recorder) { double("recorder").as_null_object }
    before do
      Akane::Receivers::Stream.stub(new: receiver)
      Akane::Recorder.stub(new: recorder)

      @on_event, @on_tweet, @on_delete, @on_message = nil
      receiver.stub(name: 'a')
      receiver.stub(:on_event)   { |&block| @on_event   = block }
      receiver.stub(:on_tweet)   { |&block| @on_tweet   = block }
      receiver.stub(:on_delete)  { |&block| @on_delete  = block }
      receiver.stub(:on_message) { |&block| @on_message = block }

      subject.prepare
    end

    it "starts all receivers" do
      receiver.should_receive(:start)
      subject.start
    end

    it "starts all receivers" do
      recorder.should_receive(:run)
      subject.start
    end

    it "sends all to recorder" do
      subject.start

      recorder.should_receive(:record_tweet).with('a', "id" => 42)
      recorder.should_receive(:record_event).with('a', "event" => 'favorite')
      recorder.should_receive(:mark_as_deleted).with('a', 5, 420)
      recorder.should_receive(:record_message).with('a', 'mes' => 'sage')

      @on_tweet.call("id" => 42)
      @on_event.call("event" => 'favorite')
      @on_delete.call(5, 420)
      @on_message.call('mes' => 'sage')
    end
  end

  describe "#run" do
    it "calls setup then start"
  end
end
