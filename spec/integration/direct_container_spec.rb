require 'spec_helper'

describe "Direct containers" do
  describe "#directly_contains" do

    context "when the class is an ActiveFedora::Base"  do
      before do
        class Forest < ActiveFedora::Base
          directly_contains :trees, has_member_relation: ::RDF::URI.new("http://example.com/hasTrees"), class_name: "ActiveFedora::Base"
        end
      end
      after do
        Object.send(:remove_const, :Forest)
      end

      let(:forest)  { Forest.new }
      let(:tree)    { forest.trees.build }

      context "when parent has not been saved" do
        it "can build children" do
          built_tree = forest.trees.build
          expect(forest.trees).to include(built_tree)
        end
      end

      context "when parent has been saved" do
        before { forest.save }
        it "can build children" do
          built_tree = forest.trees.build
          expect(forest.trees).to include(built_tree)
        end
      end

    end

    context "when the class is ActiveFedora::File" do
      before do
        class FooHistory < ActiveFedora::Base
          directly_contains :files, has_member_relation: ::RDF::URI.new("http://example.com/hasFiles")
        end
      end
      after do
        Object.send(:remove_const, :FooHistory)
      end

      let(:file) { o.files.build }
      let(:reloaded) { FooHistory.find(o.id) }
      let(:o) { FooHistory.new }

      context "with no files" do
        subject { o.files }
        let(:o) { FooHistory.new }

        it { is_expected.to be_empty }
        it { is_expected.to eq [] }
      end

      context "when the object has not been saved" do
        it "can build children" do
          built_file = o.files.build
          expect(o.files).to include(built_file)
        end
      end

      context "when the object exists" do
        let(:o) { FooHistory.create }

        before do
          file.content = "HMMM"
          o.save
        end

        describe "#first" do
          subject(:first_file) { reloaded.files.first }
          it "has the content" do
            expect(first_file.content).to eq 'HMMM'
          end
        end

        describe "#to_a" do
          subject(:files) { reloaded.files }
          it "has the content" do
            expect(files.to_a).to eq [file]
          end
        end

        describe "#append" do
          let(:file2) { o.files.build }
          it "has two files" do
            expect(o.files).to contain_exactly file, file2
          end

          context "and then saved/reloaded" do
            before do
              file2.content = "Derp"
              o.save!
            end
            it "has two files" do
              expect(reloaded.files).to contain_exactly file, file2
            end
          end
        end
      end

      context "when the object is new" do
        let(:o) { FooHistory.new }
        let(:file) { o.files.build }

        it "fails" do
          # This is the expected behavior right now. In the future make the uri get assigned by autosave.
          expect { o.files.build }.to raise_error "Can't get uri. Owner isn't saved"
        end
      end
    end

    context "when the class is a subclass of ActiveFedora::File" do
      before do
        class SubFile < ActiveFedora::File; end
        class FooHistory < ActiveFedora::Base
          directly_contains :files, has_member_relation: ::RDF::URI.new("http://example.com/hasFiles"), class_name: 'SubFile'
        end
      end
      after do
        Object.send(:remove_const, :FooHistory)
        Object.send(:remove_const, :SubFile)
      end

      let(:o) { FooHistory.create }
      let(:file) { o.files.build }
      let(:reloaded) { FooHistory.find(o.id) }

      describe "#build" do
        subject { file }
        it { is_expected.to be_kind_of SubFile }
      end

      context "when the object exists" do
        before do
          file.content = "HMMM"
          o.save
        end

        describe "#first" do
          subject(:first_file) { reloaded.files.first }
          it "has the content" do
            expect(first_file.content).to eq 'HMMM'
          end
        end
      end
    end

    context "when using is_member_of_relation" do
      before do
        class FooHistory < ActiveFedora::Base
          directly_contains :files, is_member_of_relation: ::RDF::URI.new("http://example.com/isWithin")
        end
      end
      after do
        Object.send(:remove_const, :FooHistory)
      end

      let(:file) { o.files.build }
      let(:reloaded) { FooHistory.find(o.id) }

      context "with no files" do
        subject { o.files }
        let(:o) { FooHistory.new }

        it { is_expected.to be_empty }
        it { is_expected.to eq [] }
      end

      context "when the object exists" do
        let(:o) { FooHistory.create }

        before do
          file.content = "HMMM"
          o.save
        end

        describe "#first" do
          subject(:first_file) { reloaded.files.first }
          it "has the content" do
            expect(first_file.content).to eq 'HMMM'
          end
        end
      end
    end

    context "deleting members" do
      before do
        class FooHistory < ActiveFedora::Base
          directly_contains :files, is_member_of_relation: ::RDF::URI.new("http://example.com/isWithin")
        end
      end
      after do
        Object.send(:remove_const, :FooHistory)
      end

      describe "#delete the contained object directly" do
        let(:history) { FooHistory.create }
        let(:file1) { history.files.build }
        let(:file2) { history.files.build }

        before do
          file1.content = "hello"
          file2.content = "hola"
          history.save
          history.reload
        end

        it "deletes the contained resource directly" do
          expect(history.files).to contain_exactly file1, file2
          file1.delete
          history.reload
          expect(history.files).to eq [file2]
        end
      end

      describe "#delete via the collection proxy" do
        let(:history) { FooHistory.create }
        let(:file1) { history.files.build }
        let(:file2) { history.files.build }

        before do
          file1.content = "hello"
          file2.content = "hola"
          history.save
          history.reload
        end

        it "deletes the contained resource via the collection proxy" do
          expect(history.reload.files).to contain_exactly file1, file2
          history.files.delete(file1)
          expect(history.reload.files).to eq [file2]
        end
      end
    end
  end

  describe "#include?" do
    before do
      class FooHistory < ActiveFedora::Base
        directly_contains :files, has_member_relation: ::RDF::URI.new('http://example.com/hasFiles')
      end
    end

    after do
      Object.send(:remove_const, :FooHistory)
    end

    let(:foo) { FooHistory.create }

    let!(:file1) { foo.files.build }

    before do
      file1.content = 'hmm'
      foo.save
    end

    context "when it is not loaded" do
      context "and it contains the file" do
        subject { foo.reload.files.include? file1 }
        it { is_expected.to be true }
      end

      context "and it doesn't contain the file" do
        let!(:file2) { ActiveFedora::File.new { |f| f.content = 'hmm'; f.save } }
        subject { foo.reload.files.include? file2 }
        it { is_expected.to be false }
      end
    end

    context "when it is loaded" do
      before { foo.files.to_a } # initial load of the association

      context "and it contains the file" do
        subject { foo.files.include? file1 }
        it { is_expected.to be true }
      end

      context "and it doesn't contain the file" do
        let!(:file2) { ActiveFedora::File.new { |f| f.content = 'hmm'; f.save } }
        subject { foo.files.include? file2 }
        it { is_expected.to be false }
      end
    end
  end
end
