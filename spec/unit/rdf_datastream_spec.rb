# -*- encoding: utf-8 -*-
require 'spec_helper'

describe ActiveFedora::RDFDatastream do
  describe "a new instance" do
    subject { ActiveFedora::RDFDatastream.new(double(new_record?: true, uri: '/test:1') , 'descMetadata') }
    its(:metadata?) { should be_true}
    its(:content_changed?) { should be_false}
  end
  describe "an instance that exists in the datastore, but hasn't been loaded" do
    before do
      class MyDatastream < ActiveFedora::NtriplesRDFDatastream
        property :title, :predicate => RDF::DC.title
        property :description, :predicate => RDF::DC.description, :multivalue => false
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
      subject.should_not_receive(:retrieve_content)
      subject.should_not be_content_changed
    end

    it "should allow asserting an empty string" do
      subject.title = ['']
      subject.title.should == ['']
    end

    describe "when multivalue: false" do
      it "should return single values" do
        subject.description = 'my description'
        subject.description.should == 'my description'
      end
    end

    it "should clear stuff" do
      subject.title = ['one', 'two', 'three']
      subject.title.clear
      subject.graph.query([subject.rdf_subject,  RDF::DC.title, nil]).first.should be_nil
    end

    it "should have a list of fields" do
      MyDatastream.fields.should == [:title, :description]
    end
  end

  describe "deserialize" do
    subject { ActiveFedora::NtriplesRDFDatastream.new(double(new_record?: true, uri: '/test:1') , 'descMetadata') }
    it "should be able to handle non-utf-8 characters" do
      # see https://github.com/ruby-rdf/rdf/issues/142
      data = "<info:fedora/scholarsphere:qv33rx50r> <http://purl.org/dc/terms/description> \"\\n\xE2\x80\x99 \" .\n".force_encoding('ASCII-8BIT')

      result = subject.deserialize(data)
      result.dump(:ntriples).should == "<info:fedora/scholarsphere:qv33rx50r> <http://purl.org/dc/terms/description> \"\\n’ \" .\n"
    end
  end

  describe 'content=' do
    let(:ds) {ActiveFedora::NtriplesRDFDatastream.new}
    it "should be able to handle non-utf-8 characters" do
      data = "<info:fedora/scholarsphere:qv33rx50r> <http://purl.org/dc/terms/description> \"\\n\xE2\x80\x99 \" .\n".force_encoding('ASCII-8BIT')
      ds.content = data
      expect(ds.resource.dump(:ntriples)).to eq "<info:fedora/scholarsphere:qv33rx50r> <http://purl.org/dc/terms/description> \"\\n’ \" .\n"
    end
  end

  describe 'legacy non-utf-8 characters' do
    let(:ds) do
      datastream = ActiveFedora::NtriplesRDFDatastream.new
      datastream.stub(:new?).and_return(false)
      datastream.stub(:datastream_content).and_return("<info:fedora/scholarsphere:qv33rx50r> <http://purl.org/dc/terms/description> \"\\n\xE2\x80\x99 \" .\n".force_encoding('ASCII-8BIT'))
      datastream
    end
    it "should not error on access" do
      expect(ds.resource.dump(:ntriples)).to eq "<info:fedora/scholarsphere:qv33rx50r> <http://purl.org/dc/terms/description> \"\\n’ \" .\n"
    end
  end

end
