require 'spec_helper'

describe 'Codegen: super' do
  it "codegens super without arguments" do
    run("class Foo; def foo; 1; end; end; class Bar < Foo; def foo; super; end; end; Bar.new.foo") { 1 }
  end

  it "codegens super without arguments but parent has arguments" do
    run("class Foo; def foo(x); x + 1; end; end; class Bar < Foo; def foo(x); super; end; end; Bar.new.foo(1)") { 2 }
  end

  it "codegens super without arguments and instance variable" do
    run("class Foo; def foo; @x = 1; end; end; class Bar < Foo; def foo; super; end; end; Bar.new.foo") { 1 }
  end

  it "codegens super that calls subclass method" do
    run("
      class Foo
        def foo
          bar
        end

        def bar
          1
        end
      end

      class Bar < Foo
        def foo
          super
        end

        def bar
          2
        end
      end

      b = Bar.new
      b.foo
      ").to_i.should eq(2)
  end

  it "codegens super that calls subclass method 2" do
    run("
      class Foo
        def foo
          self.bar
        end

        def bar
          1
        end
      end

      class Bar < Foo
        def foo
          super
        end

        def bar
          2
        end
      end

      b = Bar.new
      b.foo
      ").to_i.should eq(2)
  end
end
