require 'spec_helper'
require 'akane/receivers/abstract_receiver'

describe Akane::Receivers::AbstractReceiver do
=begin
  subject { described_class.new(consumer: {token: 'consumer-token', secret: 'consumer-secret'}, account: {token: '42-access-token', secret: 'access-secret'}) }
  describe "#start" do
    it "starts listening" do
      subject.start
    end

    it "starts returning running? true" do
      expect { subject.start } \
        .to change { subject.running? } \
        .from(false).to(true)
    end
  end

  describe "#stop" do
    it "stops listening" do
      subject.stop
    end

    it "stops returning running? true" do
      subject.start

      expect { subject.stop } \
        .to change { subject.running? } \
        .from(true).to(false)
    end
  end

  describe "when received tweet" do
    it "calls on_tweet hook" do
    end
  end

  describe "when received event" do
    it "calls on_event hook" do
    end
  end

  describe "when error occured" do
    it "calls on_error hook" do
    end
  end
=end
end
