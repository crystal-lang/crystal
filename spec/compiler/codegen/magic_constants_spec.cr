require "../../spec_helper"

describe "Code gen: magic constants" do
  it "does __LINE__" do
    run(%(
      def foo(x = __LINE__)
        x
      end

      foo
      ), inject_primitives: false).to_i.should eq(6)
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
      ), inject_primitives: false).to_i.should eq(11)
  end

  it "does __LINE__ when specifying one default arg with __FILE__" do
    run(%(
      def foo(x, file = __FILE__, line = __LINE__)
        line
      end

      foo 1, "hello"
      ), inject_primitives: false).to_i.should eq(6)
  end

  it "does __LINE__ when specifying one normal default arg" do
    run(%(
      require "primitives"

      def foo(x, z = 10, line = __LINE__)
        z &+ line
      end

      foo 1, 20
      ), inject_primitives: false).to_i.should eq(28)
  end

  it "does __LINE__ when specifying one middle argument" do
    run(%(
      require "primitives"

      def foo(x, line = __LINE__, z = 1)
        z &+ line
      end

      foo 1, z: 20
      ), inject_primitives: false).to_i.should eq(28)
  end

  it "does __LINE__ in macro" do
    run(%(
      macro foo(line = __LINE__)
        {{line}}
      end

      foo
      ), inject_primitives: false).to_i.should eq(6)
  end

  it "does __FILE__ in macro" do
    run(%(
      macro foo(file = __FILE__)
        {{file}}
      end

      foo
      ), filename: "/foo/bar/baz.cr").to_string.should eq("/foo/bar/baz.cr")
  end

  it "does __DIR__ in macro" do
    run(%(
      macro foo(dir = __DIR__)
        {{dir}}
      end

      foo
      ), filename: "/foo/bar/baz.cr").to_string.should eq("/foo/bar")
  end

  it "does __END_LINE__ without block" do
    run(%(
      def foo(x = __END_LINE__)
        x
      end

      foo
      ), inject_primitives: false).to_i.should eq(6)
  end

  it "does __END_LINE__ with block" do
    run(%(
      def foo(x = __END_LINE__)
        yield
        x
      end

      foo do
        1
      end
      ), inject_primitives: false).to_i.should eq(9)
  end

  it "does __END_LINE__ in macro without block" do
    run(%(
      macro foo(line = __END_LINE__)
        {{line}}
      end

      foo
      ), inject_primitives: false).to_i.should eq(6)
  end

  it "does __END_LINE__ in macro with block" do
    run(%(
      macro foo(line = __END_LINE__)
        {{line}}
      end

      foo do
        1
      end
      ), inject_primitives: false).to_i.should eq(8)
  end
end
