require 'spec_helper'

describe ActiveFedora::Base do
  before :all do
    class ValidationStub < ActiveFedora::Base
      property :fubar, predicate: ::RDF::URI('http://example.com/fubar')
      property :swank, predicate: ::RDF::URI('http://example.com/swank'), multiple: false

      validates_presence_of :fubar
      validates_length_of :swank, minimum: 5
    end
  end

  subject { ValidationStub.new }

  after :all do
    Object.send(:remove_const, :ValidationStub)
  end

  describe "a valid object" do
    before do
      subject.attributes = { fubar: ['here'], swank: 'long enough' }
    end

    it { should be_valid }
  end
  describe "an invalid object" do
    before do
      subject.attributes = { swank: 'smal' }
    end
    it "has errors" do
      expect(subject).to_not be_valid
      expect(subject.errors[:fubar]).to eq ["can't be blank"]
      expect(subject.errors[:swank]).to eq ["is too short (minimum is 5 characters)"]
    end
  end

  describe "required terms" do
    it { should be_required(:fubar) }
    it { should_not be_required(:swank) }
  end

  describe "#save!" do
    before { allow(subject).to receive(:_create_record) } # prevent saving to Fedora/Solr

    it "validates only once" do
      expect(subject).to receive(:perform_validations).once.and_return(true)
      subject.save!
    end
  end
end
