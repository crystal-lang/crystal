require "../../spec_helper"

describe "Codegen: special vars" do
  ["$~", "$?"].each do |name|
    it "codegens #{name}" do
      run(%(
        class Object; def not_nil!; self; end; end

        def foo(z)
          #{name} = "hey"
        end

        foo(2)
        #{name}
        )).to_string.should eq("hey")
    end

    it "codegens #{name} with nilable (1)" do
      run(%(
        require "prelude"

        def foo
          if 1 == 2
            #{name} = "foo"
          end
        end

        foo

        begin
          #{name}
        rescue ex
          "ouch"
        end
        )).to_string.should eq("ouch")
    end

    it "codegens #{name} with nilable (2)" do
      run(%(
        require "prelude"

        def foo
          if 1 == 1
            #{name} = "foo"
          end
        end

        foo

        begin
          #{name}
        rescue ex
          "ouch"
        end
        )).to_string.should eq("foo")
    end
  end

  it "codegens $~ two levels" do
    run(<<-CRYSTAL).to_string.should eq("hey")
      class Object; def not_nil!; self; end; end

      def foo
        $? = "hey"
      end

      def bar
        $? = foo
        $?
      end

      bar
      $?
      CRYSTAL
  end

  it "works lazily" do
    run(<<-CRYSTAL).to_string.should eq("bar")
      require "prelude"

      class Foo
        getter string

        def initialize(@string : String)
        end
      end

      def bar(&block : Foo -> _)
        block
      end

      block = bar do |foo|
        case foo.string
        when /foo-(.+)/
          $1
        else
          "baz"
        end
      end
      block.call(Foo.new("foo-bar"))
      CRYSTAL
  end

  it "codegens in block" do
    run(<<-CRYSTAL).to_string.should eq("hey")
      require "prelude"

      class Object; def not_nil!; self; end; end

      def foo
        $~ = "hey"
        yield
      end

      a = nil
      foo do
        a = $~
      end
      a.not_nil!
      CRYSTAL
  end

  it "codegens in block with nested block" do
    run(<<-CRYSTAL).to_string.should eq("hey")
      require "prelude"

      class Object; def not_nil!; self; end; end

      def bar
        yield
      end

      def foo
        bar do
          $~ = "hey"
          yield
        end
      end

      a = nil
      foo do
        a = $~
      end
      a.not_nil!
      CRYSTAL
  end

  it "codegens after block" do
    run(<<-CRYSTAL).to_string.should eq("hey")
      require "prelude"

      class Object; def not_nil!; self; end; end

      def foo
        $~ = "hey"
        yield
      end

      a = nil
      foo {}
      $~
      CRYSTAL
  end

  it "codegens after block 2" do
    run(<<-CRYSTAL).to_string.should eq("bye")
      class Object; def not_nil!; self; end; end

      def baz
        $~ = "bye"
      end

      def foo
        baz
        yield
        $~
      end

      foo do
      end
      CRYSTAL
  end

  it "codegens with default argument" do
    run(<<-CRYSTAL).to_string.should eq("bye")
      class Object; def not_nil!; self; end; end

      def baz(x = 1)
        $~ = "bye"
      end

      baz
      $~
      CRYSTAL
  end

  it "preserves special vars in macro expansion with call with default arguments (#824)" do
    run(<<-CRYSTAL).to_string.should eq("yes")
      class Object; def not_nil!; self; end; end

      def bar(x = 0)
        $~ = "yes"
      end

      macro foo
        bar
        $~
      end

      foo
      CRYSTAL
  end

  it "allows with primitive" do
    run(<<-CRYSTAL).to_i.should eq(123)
      class Object; def not_nil!; self; end; end

      def foo
        $~ = 123
      end

      foo

      v = $~
      v || 456
      CRYSTAL
  end

  it "allows with struct" do
    run(<<-CRYSTAL).to_i.should eq(123)
      class Object; def not_nil!; self; end; end

      struct Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      def foo
        $~ = Foo.new(123)
      end

      foo

      v = $~
      if v
        v.x
      else
        456
      end
      CRYSTAL
  end

  it "preserves special vars if initialized inside block (#2194)" do
    run(<<-CRYSTAL).to_string.should eq("foo")
      class Object; def not_nil!; self; end; end

      def foo
        $~ = "foo"
      end

      def bar
        yield
      end

      bar do
        foo
      end

      v = $~
      if v
        v
      else
        "bar"
      end
      CRYSTAL
  end
end
