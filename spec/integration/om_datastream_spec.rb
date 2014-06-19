require 'spec_helper'

describe ActiveFedora::OmDatastream do
  before(:all) do
    class ModsArticle2 < ActiveFedora::Base
      # Uses the Hydra MODS Article profile for tracking most of the descriptive metadata
      has_metadata "descMetadata", type: Hydra::ModsArticleDatastream, autocreate: true
    end
  end

  after(:all) do
    Object.send(:remove_const, :ModsArticle2)
  end

  let(:obj) { ModsArticle2.create.reload }

  after(:each) do
    obj.destroy
  end

  subject { obj.descMetadata }

  describe "#changed?" do
    it "should not be changed when no fields have been set" do
      subject.should_not be_content_changed
    end
    it "should be changed when a field has been set" do
      subject.title = 'Foobar'
      subject.should be_content_changed
    end
    it "should not be changed if the new xml matches the old xml" do
      subject.content = subject.content
      subject.should_not be_changed
    end

    it "should be changed if there are minor differences in whitespace" do
      subject.content = "<a><b>1</b></a>"
      obj.save
      subject.should_not be_changed
      subject.content = "<a>\n<b>1</b>\n</a>"
      subject.should be_changed
    end
  end

  describe "empty datastream content" do
    it "should not break when there is empty datastream content" do
      subject.content = ""
      obj.save
    end
  end

  describe '.update_values' do
    before do
      subject.content = File.read(fixture('mods_articles/mods_article1.xml'))
      obj.save
      obj.reload
    end

    it "should not be dirty after .update_values is saved" do
      obj.descMetadata.update_values([{:name=>0},{:role=>0},:text] =>"Funder")
      obj.descMetadata.should be_changed
      obj.save
      obj.descMetadata.should_not be_changed
      obj.descMetadata.term_values({:name=>0},{:role=>0},:text).should == ["Funder"]
    end    
  end


  describe ".to_solr" do
    before do
      subject.journal.issue.publication_date = Date.parse('2012-11-02')
      obj.save!
      obj.reload
    end
    it "should solrize terms with :type=>'date' to *_dt solr terms" do
      obj.to_solr[ActiveFedora::SolrService.solr_name('desc_metadata__journal_issue_publication_date', type: :date)].should == ['2012-11-02T00:00:00Z']
    end
  end
end
