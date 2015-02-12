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
    run(%(
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
      )).to_string.should eq("hey")
  end
end
