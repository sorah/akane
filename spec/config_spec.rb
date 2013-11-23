require 'spec_helper'
require 'logger'
require 'akane/config'

describe Akane::Config do
  subject { described_class.new("log" => File::NULL, "foo" => "bar") }

  describe "#logger" do
    it "returns logger" do
      expect(subject.logger).to be_a_kind_of(Logger)
    end
  end

  describe "#[]" do
    it "returns from config hash" do
      expect(subject["foo"]).to eq "bar"
    end
  end
end
