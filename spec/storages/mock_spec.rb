require 'spec_helper'
require 'akane/storages/mock'

describe Akane::Storages::Mock do
  let(:config) { {} }
  subject { described_class.new(config: config, logger: Logger.new(nil)) }

  describe "#record_tweet" do
    it "records in memory" do
      described_class.recorded_tweets.clear
      expect { subject.record_tweet('a', "id" => 42) } \
        .to change { described_class.recorded_tweets.last } \
        .from(nil).to(['a', "id" => 42])
    end
  end

  describe "#mark_as_deleted" do
    it "records in memory" do
      described_class.deletion_marks.clear
      expect { subject.mark_as_deleted('a', 1, 42) } \
        .to change { described_class.deletion_marks.last } \
        .from(nil).to(['a', 1, 42])
    end
  end

  describe "#record_event" do
    it "records in memory" do
      described_class.recorded_events.clear
      expect { subject.record_event('a', 'event' => 'some') } \
        .to change { described_class.recorded_events.last } \
        .from(nil).to(['a', 'event' => 'some'])
    end
  end

  describe "#record_message" do
    it "records in memory" do
      described_class.recorded_messages.clear
      expect { subject.record_message('a', 'id' => 10) } \
        .to change { described_class.recorded_messages.last } \
        .from(nil).to(['a', 'id' => 10])
    end
  end

  describe ".reset!" do
    it "flushes all recorded" do
      described_class.recorded_tweets << 1
      described_class.recorded_events << 1
      described_class.recorded_messages << 1
      described_class.deletion_marks << 1

      expect { described_class.reset! } \
        .to change { [described_class.recorded_tweets,
                      described_class.recorded_messages,
                      described_class.recorded_events,
                      described_class.deletion_marks].map(&:empty?) } \
        .from([false,false,false,false]).to([true,true,true,true])
    end
  end
end
