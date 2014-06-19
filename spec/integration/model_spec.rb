require 'spec_helper'

describe ActiveFedora::Model do
  
  before(:each) do 
    module ModelIntegrationSpec
      
      class Base < ActiveFedora::Base
        include ActiveFedora::Model
        def self.pid_namespace
          "foo"
        end
        has_metadata :name => "properties", :type => ActiveFedora::SimpleDatastream, :autocreate => true 
      end
      class Basic < Base
      end
    end

    @test_instance = ModelIntegrationSpec::Basic.new
    @test_instance.save
    
  end
  
  after(:each) do
    @test_instance.delete
    Object.send(:remove_const, :ModelIntegrationSpec)
  end
  
  describe "#all" do
    it "should return an array of instances of the calling Class" do
      result = ModelIntegrationSpec::Basic.all.to_a
      result.should be_instance_of(Array)
      # this test is meaningless if the array length is zero
      result.length.should > 0
      result.each do |obj|
        obj.class.should == ModelIntegrationSpec::Basic
      end
    end
  end

  describe '#find' do
    describe "#find with a valid pid without cast" do
      subject { ActiveFedora::Base.find(@test_instance.pid) }
      it { should be_instance_of ModelIntegrationSpec::Basic}
    end
    describe "#find with a valid pid with cast of false" do
      subject { ActiveFedora::Base.find(@test_instance.pid, cast: false) }
      it { should be_instance_of ActiveFedora::Base}
    end
    describe "#find with a valid pid without cast on a model extending Base" do
      subject { ModelIntegrationSpec::Basic.find(@test_instance.pid) }
      it { should be_instance_of ModelIntegrationSpec::Basic}
    end
  end
end
