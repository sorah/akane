require 'spec_helper'
require 'logger'
require 'akane/storages/abstract_storage'

describe Akane::Storages::AbstractStorage do
  let(:config) { {} }
  subject { described_class.new(config: config, logger: Logger.new(nil)) }

  describe "#record_tweet" do
  end

  describe "#mark_as_deleted" do
  end

  describe "#record_event" do
  end

  describe "#record_message" do
  end
end
