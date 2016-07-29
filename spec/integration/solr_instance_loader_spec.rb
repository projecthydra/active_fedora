require 'spec_helper'

describe ActiveFedora::SolrInstanceLoader do
  before do
    class MyDS < ActiveFedora::OmDatastream
      set_terminology do |t|
        t.root(path: "durh")
        t.foo
        t.bar
      end
    end

    class Foo < ActiveFedora::Base
      has_subresource 'descMetadata', class_name: 'MyDS'
      property :title, predicate: ::RDF::Vocab::DC.title, multiple: false
      property :description, predicate: ::RDF::Vocab::DC.description
      belongs_to :another, predicate: ActiveFedora::RDF::Fcrepo::RelsExt.isPartOf, class_name: 'Foo'
      has_and_belongs_to_many :dates, predicate: ::RDF::Vocab::DC.date, class_name: 'Bar'
      accepts_nested_attributes_for :dates, reject_if: :all_blank, allow_destroy: true
    end
    class Bar < ActiveFedora::Base
      property :start, predicate: ::RDF::Vocab::EDM.begin, multiple: false
      has_many :foos, inverse_of: :dates, class_name: 'Foo'
    end
  end

  let(:another) { Foo.create }

  let!(:obj) { Foo.create!(
    id: 'test-123',
    title: 'My Title',
    description: ['first desc', 'second desc'],
    another_id: another.id,
    dates_attributes: [{ start: "2003" }, { start: "1996" }]
  ) }

  after do
    Object.send(:remove_const, :Foo)
    Object.send(:remove_const, :Bar)
    Object.send(:remove_const, :MyDS)
  end

  context "without a solr doc" do
    subject { loader.object }

    context "with context" do
      let(:loader) { described_class.new(Foo, obj.id) }

      it "finds the document in solr" do
        expect(subject).to be_instance_of Foo
        expect(subject.title).to eq 'My Title'
        expect(subject.description).to match_array ['first desc', 'second desc']
        expect(subject.another_id).to eq another.id
      end

      it "does not be mutable" do
        expect { subject.title = 'Foo' }.to raise_error ActiveFedora::ReadOnlyRecord
      end

      it "loads the correct number of nested attributes" do
        expect(subject.date_ids.count).to eq 2
      end

      it "loads the correct number of regular attributes" do
        expect(subject.description.count).to eq 2
      end
    end

    context "without context" do
      let(:loader) { described_class.new(ActiveFedora::Base, obj.id) }

      it "finds the document in solr" do
        expect_any_instance_of(ActiveFedora::File).to_not receive(:retrieve_content)
        expect_any_instance_of(Ldp::Client).to_not receive(:get)
        object = loader.object
        expect(object).to be_instance_of Foo
        expect(object.title).to eq 'My Title' # object assertion

        # and it's frozen
        expect { object.title = 'changed' }.to raise_error ActiveFedora::ReadOnlyRecord
        expect(object.title).to eq 'My Title'
      end
    end

    context "with children" do
      let(:loader) { described_class.new(Foo, obj.id) }

      it "has stub implementation of the children" do
        expect(subject.descMetadata).to be_kind_of ActiveFedora::LoadableFromJson::SolrBackedMetadataFile
      end
    end
  end

  context "with a solr doc" do
    let(:profile) { { "foo" => ["baz"], "bar" => "quix", "title" => "My Title" }.to_json }
    let(:doc) { { 'id' => 'test-123', 'has_model_ssim' => ['Foo'], 'object_profile_ssm' => profile } }
    let(:loader) { described_class.new(Foo, obj.id, doc) }

    subject { loader.object }

    it "finds the document in solr" do
      expect(subject).to be_instance_of Foo
      expect(subject.title).to eq 'My Title'
    end
  end

  context "when the model has imperfect json" do
    let(:doc) { { 'id' => 'test-123', 'has_model_ssim' => ['Foo'], 'object_profile_ssm' => profile } }
    let(:loader) { described_class.new(Foo, obj.id, doc) }
    context "when the json has extra values in it" do
      let(:profile) { { "foo" => ["baz"], "bar" => "quix", "title" => "My Title", "extra_value" => "Bonus values!" }.to_json }
      it "loads the object without trouble" do
        expect(loader.object).to be_instance_of Foo
      end
    end

    context "when the json is missing values" do
      let(:profile) { { "foo" => ["baz"], "bar" => "quix" }.to_json }
      it "loads the object without trouble" do
        expect(loader.object).to be_instance_of Foo
      end
      it "missing scalar should be nil" do
        expect(loader.object.title).to be_nil
      end
      it "missing multi-value should be []" do
        expect(loader.object.description).to eql([])
      end
    end

    context "when the json has scalar where multi-value is expected" do
      let(:profile) { { "foo" => ["baz"], "bar" => "quix", "description" => "test description" }.to_json }
      it "loads the object without trouble" do
        expect(loader.object).to be_instance_of Foo
      end
      it "converts the scalar to an array" do
        expect(loader.object.description).to eql(["test description"])
      end
    end
  end

  describe "loading system properties" do
    before { allow(Deprecation).to receive(:warn) }
    let(:obj_solr) { Foo.load_instance_from_solr(obj.id) }
    it "loads create_date from solr" do
      expect(obj.create_date).to be_present
      expect(obj_solr).to be_present
      expect(obj_solr.create_date).to be_a DateTime
    end

    it "loads modified_date from solr" do
      expect(obj.modified_date).to be_present
      expect(obj_solr).to be_present
      expect(obj_solr.modified_date).to be_a DateTime
    end
  end
end
