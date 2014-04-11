require "../../spec_helper"

describe "Code gen: exception" do
  it "codegens rescue specific leaf exception" do
    run(%(
      require "prelude"

      class Foo < Exception
      end

      def foo
        raise Foo.new
      end

      def bar(x)
        1
      end

      begin
        foo
        2
      rescue ex : Foo
        bar(ex)
      end
      )).to_i.should eq(1)
  end
end
