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
        A = 2.5

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
        A = 2.5

        def foo
          A
        end
      end

      A
      Foo.new.foo
    )).to_f.should eq(2.5)
  end
end
