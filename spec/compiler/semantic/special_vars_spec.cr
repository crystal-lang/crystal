require "../../spec_helper"

describe "Semantic: special vars" do
  ["$~", "$?"].each do |name|
    it "infers #{name}" do
      assert_type(%(
        class Object; def not_nil!; self; end; end

        def foo
          #{name} = "hey"
        end

        foo
        #{name}
        )) { nilable string }
    end

    it "types #{name} when not defined as no return" do
      assert_type(%(
        require "prelude"

        #{name}
        )) { no_return }
    end

    it "types #{name} when not defined as no return (2)" do
      assert_type(%(
        class Object; def not_nil!; self; end; end

        def foo
          #{name} = "hey"
          #{name}
        end

        foo
        )) { nilable string }
    end

    it "errors if assigning #{name} at top level" do
      assert_error %(
        #{name} = "hey"
        ),
        "'#{name}' can't be assigned at the top level"
    end
  end

  it "infers when assigning inside block" do
    assert_type(%(
      class Object; def not_nil!; self; end; end

      def bar
        yield
      end

      def foo
        bar do
          $~ = "hello"
        end
      end

      foo
      $~
      )) { nilable string }
  end

  it "infers in block" do
    assert_type(%(
      class Object; def not_nil!; self; end; end

      def foo
        $~ = "hey"
        yield
      end

      a = nil
      foo do
        a = $~
      end
      a
      )) { nilable string }
  end

  it "infers in block with nested block" do
    assert_type(%(
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
      a
      )) { nilable string }
  end

  it "infers after block" do
    assert_type(%(
      class Object; def not_nil!; self; end; end

      def foo
        $~ = "hey"
        yield
      end

      foo do
      end
      $~
      )) { nilable string }
  end
end
