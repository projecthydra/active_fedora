require 'spec_helper'

RSpec.describe ActiveFedora::Base do
  before do
    class Source < ActiveFedora::Base
      contains :sub_resource, class_name: "Source"
      property :title, predicate: ::RDF::Vocab::DC.title, multiple: false
      def save(*args)
        opts = args.first
        super.tap do
          if opts && opts[:container]
            opts[:container].title = "Demolished"
            opts[:container].save
          end
        end
      end
    end
  end
  after do
    Object.send(:remove_const, :Source)
  end

  describe "contains relationships" do
    it "is able to have RDF sources" do
      s = Source.new
      s.sub_resource.title = "Test"
      expect(s.sub_resource).not_to be_persisted
      expect { s.save }.not_to raise_error
      s.reload
      expect(s.sub_resource.title).to eq "Test"
      expect(s.sub_resource.uri).to eq s.uri.to_s + "/sub_resource"
      expect(s.title).to eq "Demolished"
    end
    it "is able to add RDF sources" do
      s = Source.create
      s.sub_resource.title = "Test"
      expect(s.sub_resource).not_to be_persisted
      expect { s.save }.not_to raise_error
      s.reload
      expect(s.sub_resource.title).to eq "Test"
      expect(s.sub_resource.uri).to eq s.uri.to_s + "/sub_resource"
    end
  end
end
