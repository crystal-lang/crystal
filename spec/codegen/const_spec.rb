require 'spec_helper'

describe 'Codegen: const' do
  it "define a constant" do
    run("A = 1; A").to_i.should eq(1)
  end

  it "support nested constant" do
    run("class B; A = 1; end; B::A").to_i.should eq(1)
  end

  it "support constant inside a def" do
    run(%q(
      class Foo
        A = 1

        def foo
          A
        end
      end

      Foo.new.foo
    )).to_i.should eq(1)
  end

  it "finds nearest constant first" do
    run(%q(
      A = 1

      class Foo
        A = 2.5f

        def foo
          A
        end
      end

      Foo.new.foo
    )).to_f.should eq(2.5)
  end

  it "allows constants with same name" do
    run(%q(
      A = 1

      class Foo
        A = 2.5f

        def foo
          A
        end
      end

      A
      Foo.new.foo
    )).to_f.should eq(2.5)
  end

  it "constants with expression" do
    run(%q(
      A = 1 + 1
      A
    )).to_i.should eq(2)
  end

  it "finds global constant" do
    run(%q(
      A = 1

      class Foo
        def foo
          A
        end
      end

      Foo.new.foo
    )).to_i.should eq(1)
  end

  it "define a constant in lib" do
    run("lib Foo; A = 1; end; Foo::A").to_i.should eq(1)
  end

  it "invokes block in const" do
    run(%q(require "prelude"; A = ["1"].map { |x| x.to_i }; A[0])).to_i.should eq(1)
  end

  it "declare constants in right order" do
    run("A = 1 + 1; B = true ? A : 0; B").to_i.should eq(2)
  end
end
