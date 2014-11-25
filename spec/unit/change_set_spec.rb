require 'spec_helper'

describe ActiveFedora::ChangeSet do
  let(:change_set) { described_class.new(base, base.resource, base.changed_attributes.keys) }
  subject { change_set }

  context "with an unchanged object" do
    let(:base) { ActiveFedora::Base.new }

    it { is_expected.to be_empty }
  end

  context "with a changed object" do
    before do
      class Library < ActiveFedora::Base
      end

      class Book < ActiveFedora::Base
        belongs_to :library, predicate: ActiveFedora::RDF::FedoraRelsExt.hasConstituent
        property :title, predicate: ::RDF::DC.title
      end

      base.library_id = 'foo'
      base.title = ['bar']
    end
    after do
      Object.send(:remove_const, :Library)
      Object.send(:remove_const, :Book)
    end

    let(:base) { Book.create }


    describe "#changes" do
      subject { change_set.changes }

      it { is_expected.to be_kind_of Hash }

      it "should have two elements" do
        expect(subject.size).to eq 2
      end
    end

    it { is_expected.to_not be_empty }
  end
end
