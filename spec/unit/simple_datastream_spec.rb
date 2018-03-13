require 'spec_helper'

describe ActiveFedora::SimpleDatastream do

  before do
    @sample_xml =  "<fields><coverage>coverage1</coverage><coverage>coverage2</coverage><creation_date>2012-01-15</creation_date><mydate>fake-date</mydate><prefix>foobar</prefix><publisher>publisher1</publisher></fields>"
    @test_ds = ActiveFedora::SimpleDatastream.from_xml(@sample_xml )
    @test_ds.field :coverage
    @test_ds.field :creation_date, :date
    @test_ds.field :mydate
    @test_ds.field :prefix
    @test_ds.field :publisher
  end

  it "from_xml should parse everything correctly" do
    expect(@test_ds.ng_xml).to be_equivalent_to @sample_xml
  end

  describe "#to_solr" do
    it "should work as expected" do
      expect(@test_ds.to_solr).to eq(
        {
          'coverage_tesim' => ['coverage1', 'coverage2'],
          'creation_date_dtsim' => '2012-01-15',
          'mydate_tesim' => 'fake-date',
          'prefix_tesim' => 'foobar',
          'publisher_tesim' => 'publisher1'
        }
      )
    end
  end

  describe '#new' do
    describe "model methods" do

      [:coverage, :mydate, :publisher].each do |el|
        it "should respond to getters and setters for the string typed #{el} element" do
          value = "Hey #{el}"
          @test_ds.send("#{el.to_s}=", value)
          expect(@test_ds.send(el).first).to eq(value)  #Looking at first because creator has 2 nodes
        end
      end

      it "should set date elements" do
        d = Date.parse('1939-05-23')
        @test_ds.creation_date = d
        expect(@test_ds.creation_date.first).to eq(d)
      end
    end
  end

  describe '.to_xml' do
    it 'should output the fields hash as Qualified Dublin Core XML' do
      @test_ds.publisher= "charlie"
      @test_ds.coverage= ["80%", "20%"]

      expect(@test_ds.to_xml).to be_equivalent_to('
        <fields>
          <coverage>80%</coverage>
          <coverage>20%</coverage>
          <creation_date>2012-01-15</creation_date>
          <mydate>fake-date</mydate>
          <prefix>foobar</prefix>
          <publisher>charlie</publisher>
        </fields>')
    end
  end

  describe "#to_solr" do
    it "should have title" do
      solr = @test_ds.to_solr
      expect(solr[ActiveFedora::SolrService.solr_name('publisher', type: :string)]).to eq("publisher1")
      expect(solr[ActiveFedora::SolrService.solr_name('creation_date', type: :date)]).to eq("2012-01-15")
    end
  end

end
