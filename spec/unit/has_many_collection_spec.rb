require 'spec_helper'

describe ActiveFedora::Associations::HasManyAssociation do
  before do 
    class Book < ActiveFedora::Base
    end
    class Page < ActiveFedora::Base
    end
  end

  after do
    Object.send(:remove_const, :Book)
    Object.send(:remove_const, :Page)
  end

  subject { Book.new('subject:a') }
  before {
    subject.stub(:new_record? => false, save: true)
  }

  it "should set the book_id attribute" do
    reflection = Book.create_reflection(:has_many, 'pages', {:property=>'predicate'}, Book)
    ActiveFedora::SolrService.stub(:query).and_return([])
    ac = ActiveFedora::Associations::HasManyAssociation.new(subject, reflection)
    ac.should_receive(:callback).twice
    object = Page.new('object:b')
    object.stub(:new_record? => false, save: true)
  
    object.should_receive(:[]=).with('book_id', subject.id)
 
    ac.concat object
  end
  
end
