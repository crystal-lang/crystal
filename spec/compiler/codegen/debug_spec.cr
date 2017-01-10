require "../../spec_helper"

describe "Code gen: debug" do
  it "codegens abstract struct (#3578)" do
    codegen(%(
      abstract struct Base
      end

      struct Foo < Base
      end

      struct Bar < Base
      end

      x = Foo.new || Bar.new
      ), debug: Crystal::Debug::All)
  end

  it "inlines instance var access through getter in debug mode" do
    run(%(
      struct Bar
        @x = 1

        def set
          @x = 2
        end

        def x
          @x
        end
      end

      class Foo
        @bar = Bar.new

        def set
          bar.set
        end

        def bar
          @bar
        end
      end

      foo = Foo.new
      foo.set
      foo.bar.x
      ), debug: Crystal::Debug::All, filename: "foo.cr").to_i.should eq(2)
  end
end
