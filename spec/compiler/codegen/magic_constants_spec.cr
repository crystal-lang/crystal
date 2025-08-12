require "../../spec_helper"

describe "Code gen: magic constants" do
  it "does __LINE__" do
    run(<<-CRYSTAL, inject_primitives: false).to_i.should eq(6)
      def foo(x = __LINE__)
        x
      end

      foo
      CRYSTAL
  end

  it "does __FILE__" do
    run(<<-CRYSTAL, filename: "/foo/bar/baz.cr").to_string.should eq("/foo/bar/baz.cr")
      def foo(x = __FILE__)
        x
      end

      foo
      CRYSTAL
  end

  it "does __DIR__" do
    run(<<-CRYSTAL, filename: "/foo/bar/baz.cr").to_string.should eq("/foo/bar")
      def foo(x = __DIR__)
        x
      end

      foo
      CRYSTAL
  end

  it "does __LINE__ with dispatch" do
    run(<<-CRYSTAL, inject_primitives: false).to_i.should eq(11)
      def foo(z : Int32, x = __LINE__)
        x
      end

      def foo(z : String)
        1
      end

      a = 1 || "hello"
      foo(a)
      CRYSTAL
  end

  it "does __LINE__ when specifying one default arg with __FILE__" do
    run(<<-CRYSTAL, inject_primitives: false).to_i.should eq(6)
      def foo(x, file = __FILE__, line = __LINE__)
        line
      end

      foo 1, "hello"
      CRYSTAL
  end

  it "does __LINE__ when specifying one normal default arg" do
    run(<<-CRYSTAL, inject_primitives: false).to_i.should eq(28)
      require "primitives"

      def foo(x, z = 10, line = __LINE__)
        z &+ line
      end

      foo 1, 20
      CRYSTAL
  end

  it "does __LINE__ when specifying one middle argument" do
    run(<<-CRYSTAL, inject_primitives: false).to_i.should eq(28)
      require "primitives"

      def foo(x, line = __LINE__, z = 1)
        z &+ line
      end

      foo 1, z: 20
      CRYSTAL
  end

  it "does __LINE__ in macro" do
    run(<<-CRYSTAL, inject_primitives: false).to_i.should eq(6)
      macro foo(line = __LINE__)
        {{line}}
      end

      foo
      CRYSTAL
  end

  it "does __FILE__ in macro" do
    run(<<-CRYSTAL, filename: "/foo/bar/baz.cr").to_string.should eq("/foo/bar/baz.cr")
      macro foo(file = __FILE__)
        {{file}}
      end

      foo
      CRYSTAL
  end

  it "does __DIR__ in macro" do
    run(<<-CRYSTAL, filename: "/foo/bar/baz.cr").to_string.should eq("/foo/bar")
      macro foo(dir = __DIR__)
        {{dir}}
      end

      foo
      CRYSTAL
  end

  it "does __END_LINE__ without block" do
    run(<<-CRYSTAL, inject_primitives: false).to_i.should eq(6)
      def foo(x = __END_LINE__)
        x
      end

      foo
      CRYSTAL
  end

  it "does __END_LINE__ with block" do
    run(<<-CRYSTAL, inject_primitives: false).to_i.should eq(9)
      def foo(x = __END_LINE__)
        yield
        x
      end

      foo do
        1
      end
      CRYSTAL
  end

  it "does __END_LINE__ in macro without block" do
    run(<<-CRYSTAL, inject_primitives: false).to_i.should eq(6)
      macro foo(line = __END_LINE__)
        {{line}}
      end

      foo
      CRYSTAL
  end

  it "does __END_LINE__ in macro with block" do
    run(<<-CRYSTAL, inject_primitives: false).to_i.should eq(8)
      macro foo(line = __END_LINE__)
        {{line}}
      end

      foo do
        1
      end
      CRYSTAL
  end
end
