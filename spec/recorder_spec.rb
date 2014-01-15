require 'spec_helper'
require 'akane/recorder'

describe Akane::Recorder do
  let(:storages) do
    [
      double("storage0")
    ]
  end
  subject { described_class.new(storages) }

  describe "recording tweets" do
    it "records tweet" do
      storages[0].should_receive(:record_tweet).with('a', {id: 42})
      subject.record_tweet('a', id: 42)
      subject.dequeue(true)
    end

    it "doesn't record tweets which already recorded recently" do
      storages[0].should_receive(:record_tweet).with('a', {id: 40})
      storages[0].should_receive(:record_tweet).with('a', {id: 42})

      subject.record_tweet('a', id: 40)
      subject.record_tweet('a', id: 42)
      subject.dequeue(true)
      subject.dequeue(true)
      subject.record_tweet('a', id: 42)
      subject.dequeue(true)
    end

    it "records retweeted tweet" do
      tweet = {id: 42, text: "foo", user: {id: 1, screen_name: "a"}}
      retweet = {id: 43, text: "RT @a: foo", user: {id: 2, screen_name: "b"}, retweeted_status: tweet}
      storages[0].should_receive(:record_tweet).with('a', retweet)
      storages[0].should_receive(:record_tweet).with('a', tweet)
      subject.record_tweet('a', retweet)
      subject.dequeue(true)
    end
  end

  describe "marking deletion" do
    it "marks as deleted" do
      subject.mark_as_deleted('foo', 1, 42)

      storages[0].should_receive(:mark_as_deleted).with('foo', 1, 42)
      subject.dequeue(true)
    end
  end

  describe "recording messages" do
    it "records message" do
      subject.record_message('foo', {id: 42})

      storages[0].should_receive(:record_message).with('foo', id: 42)
      subject.dequeue(true)
    end
  end

  describe "recording event" do
    it "records event" do
      subject.record_event('foo', {event: "favorite"})

      storages[0].should_receive(:record_event).with('foo', event: "favorite")
      subject.dequeue(true)
    end
  end

  describe "#run" do
    before do
      @th = Thread.new { subject.run(true) }
      @th.abort_on_exception = true
    end

    it "continues dequeuing the queue" do
      storages[0].should_receive(:record_tweet).with('a', {:id => 42})
      storages[0].should_receive(:record_tweet).with('b', {:id => 43})
      subject.record_tweet('a', :id => 42)
      subject.record_tweet('b', :id => 43)
      10.times { break if subject.queue_length.zero?; sleep 0.1 }
    end

    after do
      @th.kill if @th && @th.alive?
    end
  end
end
