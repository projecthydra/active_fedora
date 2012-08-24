require 'spec_helper'

describe ActiveFedora::Base do
  
  before(:each) do
    @test_object = ActiveFedora::Base.new
  end
  
  
  describe ".metadata_streams" do
    #TODO move to datastreams_spec
    it "should return all of the datastreams from the object that are kinds of SimpleDatastreams " do
      mock_mds1 = mock("metadata ds1")
      mock_mds2 = mock("metadata ds2")
      mock_fds = mock("file ds")
      mock_fds.expects(:kind_of?).with(ActiveFedora::MetadataDatastream).returns(false)
      mock_ngds = mock("nokogiri ds")
      mock_ngds.expects(:kind_of?).with(ActiveFedora::MetadataDatastream).returns(false)
      mock_ngds.expects(:kind_of?).with(ActiveFedora::NokogiriDatastream).returns(true)
      
      
      [mock_mds1,mock_mds2].each do |ds|
        ds.expects(:kind_of?).with(ActiveFedora::MetadataDatastream).returns(false)
        ds.expects(:kind_of?).with(ActiveFedora::NokogiriDatastream).returns(true)
      end
      mock_fds.stubs(:kind_of?).with(ActiveFedora::NokogiriDatastream).returns(false) 
      
      @test_object.expects(:datastreams).returns({:foo => mock_mds1, :bar => mock_mds2, :baz => mock_fds, :bork=>mock_ngds})
      
      result = @test_object.metadata_streams
      result.length.should == 3
      result.should include(mock_mds1)
      result.should include(mock_mds2)
      result.should include(mock_ngds)
    end
  end
  
  describe ".file_streams" do
    #TODO move to datastreams_spec
    it "should return all of the datastreams from the object that are kinds of SimpleDatastreams" do
      mock_fds1 = mock("file ds", :dsid => "file1")
      mock_fds1.expects(:kind_of?).with(ActiveFedora::MetadataDatastream).returns(false)
      mock_fds1.expects(:kind_of?).with(ActiveFedora::NokogiriDatastream).returns(false)
      mock_fds2 = mock("file ds", :dsid => "file2")
      mock_fds2.expects(:kind_of?).with(ActiveFedora::MetadataDatastream).returns(false)
      mock_fds2.expects(:kind_of?).with(ActiveFedora::NokogiriDatastream).returns(false)
      mock_mds = mock("metadata ds")
      mock_mds.expects(:kind_of?).with(ActiveFedora::MetadataDatastream).returns(false)
      mock_mds.expects(:kind_of?).with(ActiveFedora::NokogiriDatastream).returns(true)
      @test_object.expects(:datastreams).returns({:foo => mock_fds1, :bar=> mock_fds2, :baz => mock_mds})
      
      result = @test_object.file_streams
      result.length.should == 2
      result.should include(mock_fds1)
      result.should include(mock_fds2)

    end
    it "should skip DC and RELS-EXT datastreams" do
      mock_fds1 = mock("file ds", :dsid => "foo")
      mock_fds1.expects(:kind_of?).with(ActiveFedora::MetadataDatastream).returns(false)
      mock_fds1.expects(:kind_of?).with(ActiveFedora::NokogiriDatastream).returns(false)
      dc = mock("DC")
      dc.expects(:kind_of?).with(ActiveFedora::MetadataDatastream).returns(false)
      dc.expects(:kind_of?).with(ActiveFedora::NokogiriDatastream).returns(true)
      rels_ext = mock("RELS-EXT")
      rels_ext.expects(:kind_of?).with(ActiveFedora::MetadataDatastream).returns(false)
      rels_ext.expects(:kind_of?).with(ActiveFedora::NokogiriDatastream).returns(true)
      @test_object.expects(:datastreams).returns({:foo => mock_fds1, :dc => dc, :rels_ext => rels_ext})
      
      result = @test_object.file_streams
      result.length.should == 1
      result.should include(mock_fds1)
    end
  end

  describe ".update_index" do
    before do
      mock_conn = mock("SolrConnection")
      mock_conn.expects(:add)
      mock_conn.expects(:commit)
      mock_ss = mock("SolrService")
      mock_ss.stubs(:conn).returns(mock_conn)
      ActiveFedora::SolrService.stubs(:instance).returns(mock_ss)
    end
    
    it "should call .to_solr on all SimpleDatastreams AND RelsExtDatastreams and pass the resulting document to solr" do
      # Actually uses self.to_solr internally to gather solr info from all metadata datastreams
      mock1 = mock("ds1", :to_solr)
      mock2 = mock("ds2", :to_solr)
      mock3 = mock("RELS-EXT", :to_solr)
      
      mock_datastreams = {:ds1 => mock1, :ds2 => mock2, :rels_ext => mock3}
      mock1.expects(:solrize_profile).returns({})
      mock2.expects(:solrize_profile).returns({})
      mock3.expects(:solrize_profile).returns({})
      @test_object.expects(:datastreams).twice.returns(mock_datastreams)
      @test_object.expects(:solrize_relationships)
      @test_object.update_index
    end

    it "should call .to_solr on all RDFDatastreams and pass the resulting document to solr" do
      # Actually uses self.to_solr internally to gather solr info from all metadata datastreams
      mock1 = mock("ds1", :to_solr)
      mock2 = mock("ds2", :to_solr)
      mock3 = mock("RELS-EXT", :to_solr)
      
      mock_datastreams = {:ds1 => mock1, :ds2 => mock2, :rels_ext => mock3}
      mock1.expects(:solrize_profile).returns({})
      mock2.expects(:solrize_profile).returns({})
      mock3.expects(:solrize_profile).returns({})
      @test_object.expects(:datastreams).twice.returns(mock_datastreams)
      @test_object.expects(:solrize_relationships)
      @test_object.update_index
    end

    it "should retrieve a solr Connection and call Connection.add" do
      @test_object.update_index
    end

  end
  
  describe ".delete" do
    
    before(:each) do
    end
    
    it "should delete object from repository and index" do
      @test_object.inner_object.stubs(:delete)
      mock_conn = mock("SolrConnection")
      mock_conn.expects(:delete_by_id).with("__DO_NOT_USE__") 
      mock_conn.expects(:commit)
      mock_ss = mock("SolrService")
      mock_ss.stubs(:conn).returns(mock_conn)
      ActiveFedora::SolrService.stubs(:instance).returns(mock_ss)
      @test_object.expects(:inbound_relationships).returns({})
      @test_object.delete
    end

  end
  
  describe '#pids_from_uris' do 
    it "should strip the info:fedora/ out of a given string" do 
      ActiveFedora::Base.pids_from_uris("info:fedora/FOOBAR").should == "FOOBAR"
    end
    it "should accept an array of strings"do 
      ActiveFedora::Base.pids_from_uris(["info:fedora/FOOBAR", "info:fedora/BAZFOO"]).should == ["FOOBAR", "BAZFOO"]
    end
  end

end
