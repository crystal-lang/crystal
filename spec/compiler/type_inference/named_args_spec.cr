require "../../spec_helper"

describe "Type inference: named args" do
  it "errors if named arg not found" do
    assert_error %(
      def foo(x, y = 1, z = 2)
      end

      foo 1, w: 3
      ),
      "no argument named 'w'"
  end

  it "errors if named arg already specified" do
    assert_error %(
      def foo(x, y = 1, z = 2)
      end

      foo 1, x: 1
      ),
      "argument 'x' already specified"
  end

  it "errors if named arg not found in new" do
    assert_error %(
      class Foo
        def initialize(x, y = 1, z = 2)
        end
      end

      Foo.new 1, w: 3
      ),
      "no argument named 'w'"
  end

  it "errors if named arg already specified" do
    assert_error %(
      class Foo
        def initialize(x, y = 1, z = 2)
        end
      end

      Foo.new 1, x: 1
      ),
      "argument 'x' already specified"
  end

  it "errors if doesn't pass named arg restriction" do
    assert_error %(
      def foo(x = 1 : Int32)
      end

      foo x: 1.5
      ),
      "no overload matches"
  end

  it "errors if named arg already specified but in same position" do
    assert_error %(
      def foo(headers = nil)
      end

      foo 1, headers: 2
      ),
      "argument 'headers' already specified"
  end
end
