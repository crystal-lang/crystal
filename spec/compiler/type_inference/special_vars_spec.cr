require "../../spec_helper"

describe "Type inference: special vars" do
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

    it "errors if #{name} is not defined" do
      assert_error  %(
        #{name}
        ),
        "'#{name}' was not defined by any previous call"
    end

    it "errors if #{name} is not defined (2)" do
      assert_error  %(
        class Object; def not_nil!; self; end; end

        def foo
          #{name} = "hey"
          #{name}
        end

        foo
        ),
        "'#{name}' was not defined by any previous call"
    end

    it "errors if #{name} is not a reference nilable type" do
      assert_error  %(
        class Object; def not_nil!; self; end; end

        def foo
          #{name} = 1
        end

        foo
        #{name}
        ),
        "'#{name}' only allows reference nilable types"
    end

    it "errors if assigning #{name} at top level" do
      assert_error  %(
        #{name} = "hey"
        ),
        "'#{name}' can't be assigned at the top level"
    end
  end
end
