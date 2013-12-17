# -*- encoding: utf-8 -*-
require 'spec_helper'

describe ActiveFedora::RDFDatastream do
  describe "a new instance" do
    its(:metadata?) { should be_true}
    its(:content_changed?) { should be_false}
  end
  describe "an instance that exists in the datastore, but hasn't been loaded" do
    before do 
      class MyDatastream < ActiveFedora::NtriplesRDFDatastream
        map_predicates do |map|
          map.title(:in => RDF::DC)
        end
      end
      class MyObj < ActiveFedora::Base
        has_metadata 'descMetadata', type: MyDatastream
      end
      @obj = MyObj.new
      @obj.descMetadata.title = 'Foobar'
      @obj.save
    end
    after do
      @obj.destroy
      Object.send(:remove_const, :MyDatastream)
      Object.send(:remove_const, :MyObj)
    end
    subject { @obj.reload.descMetadata } 
    it "should not load the descMetadata datastream when calling content_changed?" do
      @obj.inner_object.repository.should_not_receive(:datastream_dissemination).with(hash_including(:dsid=>'descMetadata'))
      subject.should_not be_content_changed
    end

    it "should allow asserting an empty string" do
      @obj.descMetadata.title = ['']
      @obj.descMetadata.title.should == ['']
    end

    it "should have a list of fields" do
      MyDatastream.fields.should == [:title]
    end
  end

  describe "deserialize" do
    it "should be able to handle non-utf-8 characters" do
      # see https://github.com/ruby-rdf/rdf/issues/142
      ds = ActiveFedora::NtriplesRDFDatastream.new
      data = "<info:fedora/scholarsphere:qv33rx50r> <http://purl.org/dc/terms/description> \"\\n\xE2\x80\x99 \" .\n".force_encoding('ASCII-8BIT')
      
      result = ds.deserialize(data)
      result.dump(:ntriples).should == "<info:fedora/scholarsphere:qv33rx50r> <http://purl.org/dc/terms/description> \"\\n’ \" .\n"
    end
  end
end
