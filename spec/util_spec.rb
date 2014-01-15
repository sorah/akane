require 'spec_helper'
require 'akane/util'

describe Akane::Util do
  describe ".symbolish_hash" do
    let(:target) { {'a' => 1, 'b' => 2} }
    subject { described_class.symbolish_hash(target) }

    it { should eq(a: 1, b: 2) }

    context "with Hash" do
      let(:target) { {'a' => {'b' => 2}} }
      it { should eq(a: {b: 2}) }

      context "with nested Hash" do
        let(:target) { {'a' => {'b' => {'c' => 4}}} }
        it { should eq(a: {b: {c: 4}}) }
      end

      context "with nested Array" do
        let(:target) { {'a' => {'b' => [{'c' => 4}]}} }
        it { should eq(a: {b: [{c: 4}]}) }
      end

      context "with nested Array" do
        let(:target) { {'a' => {'b' => [{'c' => {'d' => 5}}]}} }
        it { should eq(a: {b: [{c: {d: 5}}]}) }
      end
    end

    context "with Hash in Array" do
      let(:target) { {'a' => [1,2,{'b' => 3}]} }
      it { should eq(a: [1,2,{b: 3}]) }
    end
  end
end
