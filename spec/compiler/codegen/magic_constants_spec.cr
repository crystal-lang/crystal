require "../../spec_helper"

describe "Code gen: magic constants" do
  it "does __LINE__" do
    run(%(
      def foo(x = __LINE__)
        x
      end

      foo
      )).to_i.should eq(6)
  end

  it "does __FILE__" do
    run(%(
      def foo(x = __FILE__)
        x
      end

      foo
      ), filename: "/foo/bar/baz.cr").to_string.should eq("/foo/bar/baz.cr")
  end

  it "does __DIR__" do
    run(%(
      def foo(x = __DIR__)
        x
      end

      foo
      ), filename: "/foo/bar/baz.cr").to_string.should eq("/foo/bar")
  end

  it "does __LINE__ with dispatch" do
    run(%(
      def foo(z : Int32, x = __LINE__)
        x
      end

      def foo(z : String)
        1
      end

      a = 1 || "hello"
      foo(a)
      )).to_i.should eq(11)
  end

  it "does __LINE__ when specifying one default arg with __FILE__" do
    run(%(
      def foo(x, file = __FILE__, line = __LINE__)
        line
      end

      foo 1, "hello"
      )).to_i.should eq(6)
  end

  it "does __LINE__ when specifying one normal default arg" do
    run(%(
      def foo(x, z = 10, line = __LINE__)
        z + line
      end

      foo 1, 20
      )).to_i.should eq(26)
  end

  it "does __LINE__ when specifying one middle argument" do
    run(%(
      def foo(x, line = __LINE__, z = 1)
        z + line
      end

      foo 1, z: 20
      )).to_i.should eq(26)
  end
end
