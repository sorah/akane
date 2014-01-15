require 'spec_helper'
require 'logger'
require 'akane/receivers/stream'

describe Akane::Receivers::Stream do
  let(:config) { {} }
  subject { described_class.new(consumer: {token: 'consumer-token', secret: 'consumer-secret'}, account: {token: '42-access-token', secret: 'access-secret'}, config: config, logger: Logger.new(nil)) }

  after(:each) do
    Twitter::Streaming::MockClient.clients.clear
  end

  describe "#start" do
    it "starts listening" do
      expect { subject.start; 100.times { break if subject.thread.status == 'sleep'; sleep 0.1 } } \
        .to change { Twitter::Streaming::MockClient.clients.size } \
        .by(1)
    end

    it "starts returning running? true" do
      expect { subject.start } \
        .to change { subject.running? } \
        .from(false).to(true)
    end
  end

  describe "#stop" do
    before do
      subject.start
      100.times { break if subject.thread.status == 'sleep'; sleep 0.1 }
    end

    it "stops listening" do
      expect { subject.stop } \
        .to change { Twitter::Streaming::MockClient.clients.size } \
        .by(-1)
    end

    it "stops returning running? true" do
      expect { subject.stop } \
        .to change { subject.running? } \
        .from(true).to(false)
    end
  end

  describe "when received tweet" do
    before do
      subject.start
      100.times { break if subject.thread.status == 'sleep'; sleep 0.1 }
    end

    it "calls on_tweet hook" do
      called = nil
      subject.on_tweet do |t|
        called = t
      end

      tweet = Twitter::Tweet.new(id: 1)
      Twitter::Streaming::MockClient.invoke(tweet)

      Twitter::Streaming::MockClient.invoke(:disconnect)
      subject.thread.join

      expect(called).to eq(tweet)
    end
  end

  describe "when received message" do
    before do
      subject.start
      100.times { break if subject.thread.status == 'sleep'; sleep 0.1 }
    end

    it "calls on_message hook" do
      called = nil
      subject.on_message do |m|
        called = m
      end

      message = Twitter::DirectMessage.new(id: 1)
      Twitter::Streaming::MockClient.invoke(message)

      Twitter::Streaming::MockClient.invoke(:disconnect)
      subject.thread.join

      expect(called).to eq(message)
    end
  end

  describe "when received deletion" do
    before do
      subject.start
      100.times { break if subject.thread.status == 'sleep'; sleep 0.1 }
    end

    it "calls on_delete hook" do
      called = nil
      subject.on_delete do |u,t|
        called = [u,t]
      end

      deletion = Twitter::Streaming::DeletedTweet.new(user_id: 42, id: 424242)
      Twitter::Streaming::MockClient.invoke(deletion)

      Twitter::Streaming::MockClient.invoke(:disconnect)
      subject.thread.join

      expect(called).to eq([42,424242])
    end
  end

  describe "when received event" do
    before do
      subject.start
      100.times { break if subject.thread.status == 'sleep'; sleep 0.1 }
    end

    it "calls on_event hook" do
      called = nil
      subject.on_event do |h|
        called = h
      end
      event = Twitter::Streaming::Event.new(event: 'favorite', source: {id: 1}, target: {id: 2}, target_object: {id: 3})
      Twitter::Streaming::MockClient.invoke(event)

      Twitter::Streaming::MockClient.invoke(:disconnect)
      subject.thread.join

      expect(called).to eq('event' => event.name, 'source' => event.source,
                           'target' => event.target, 'target_object' => event.target_object)
    end
  end
end
