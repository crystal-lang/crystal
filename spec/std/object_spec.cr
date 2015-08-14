require "spec"

module Test
  class TestClass
    def foo
      "foo"
    end

    alias_method :bar, :foo
  end
end

describe "Object" do
  describe "alias_method" do
    it "calls the specified method" do
      object = Test::TestClass.new
      object.bar.should eq "foo"
    end
  end
end
