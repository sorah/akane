require 'spec_helper'
require 'akane/receivers/stream'

describe Akane::Receivers::Stream do
  let(:config) { {} }
  subject { described_class.new(consumer: {token: 'consumer-token', secret: 'consumer-secret'}, account: {token: '42-access-token', secret: 'access-secret'}, config: config) }

  after(:each) do
    TweetStream::MockClient.clients.clear
  end

  describe "#start" do
    it "starts listening" do
      expect { subject.start } \
        .to change { TweetStream::MockClient.clients.size } \
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
    end

    it "stops listening" do
      expect { subject.stop } \
        .to change { TweetStream::MockClient.clients.size } \
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
    end

    it "calls on_tweet hook" do
      called = nil
      subject.on_tweet do |tweet|
        called = tweet
      end
      TweetStream::MockClient.invoke('timeline_status', foo: :bar)
      expect(called).to eq(foo: :bar)
    end
  end

  describe "when received message" do
    before do
      subject.start
    end

    it "calls on_message hook" do
      called = nil
      subject.on_message do |message|
        called = message
      end
      TweetStream::MockClient.invoke('direct_message', foo: :bar)
      expect(called).to eq(foo: :bar)
    end
  end

  describe "when received deletion" do
    before do
      subject.start
    end

    it "calls on_delete hook" do
      called = nil
      subject.on_delete do |u,t|
        called = [u,t]
      end
      TweetStream::MockClient.invoke('delete', 42, 424242)
      expect(called).to eq([42,424242])
    end
  end

  describe "when received event" do
    before do
      subject.start
    end

    it "calls on_event hook" do
      called = nil
      subject.on_event do |h|
        called = h
      end
      TweetStream::MockClient.invoke('anything', "event" => "favorite")
      expect(called).to eq("event" => "favorite")
    end
  end
end
