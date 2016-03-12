require "spec"
require "singleton"

class SingletonTest
  include Singleton
end


describe "Singleton" do
    it "returns nil on first call to instance?" do
      SingletonTest.instance?.should be_nil
    end

    it "returns the same object" do
      SingletonTest.instance.should eq(SingletonTest.instance)
      SingletonTest.instance.should eq(SingletonTest.instance?)
    end
end
