require "../../spec_helper"

describe "Code gen: next" do
  it "codegens next" do
    run("
      def foo
        yield
      end

      foo do
        next 1
      end
      ").to_i.should eq(1)
  end

  it "codegens next conditionally" do
    run("
      def foo
        yield 1
        yield 2
        yield 3
        yield 4
      end

      a = 0
      foo do |i|
        next if i % 2 == 0
        a += i
      end
      a
      ").to_i.should eq(4)
  end

  it "codegens next conditionally with int type (2)" do
    run("
      def foo
        x = 0
        x += yield 1
        x += yield 2
        x += yield 3
        x += yield 4
        x
      end

      foo do |i|
        if i == 1
          next 10
        elsif i == 2
          next 20
        elsif i == 3
          next 30
        end
        40
      end
      ").to_i.should eq(100)
  end

  it "codegens next with break (1)" do
    run("
      def foo
        yield 1
      end

      foo do |i|
        if i == 1
          break 20
        else
          next 10
        end
      end
      ").to_i.should eq(20)
  end

  it "codegens next with break (2)" do
    run("
      def foo
        a = 0
        a += yield 1
        a += yield 2
        a
      end

      foo do |i|
        if i == 1
          next 10
        elsif i == 3
          break 20
        end
        30
      end
      ").to_i.should eq(40)
  end

  it "codegens next with break (3)" do
    run("
      def foo
        a = 0
        a += yield 1
        a += yield 2
        a
      end

      foo do |i|
        if i == 1
          next 10
        elsif i == 2
          break 20
        end
        30
      end
      ").to_i.should eq(20)
  end

  it "codegens next with while inside block" do
    run("
      def foo
        a = 0
        a += yield 4
        a += yield 5
        a
      end

      foo do |i|
        a = 0
        b = 0
        while a < 4
          a += 1
          next if a % 2 == 0
          b += a
        end
        if b == i
          next 10
        end
        20
      end
      ").to_i.should eq(30)
  end

  it "codegens next without expressions" do
    run("
      struct Nil; def to_i; 0; end; end

      def foo
        yield
      end

      foo do
        if 1 == 1
          1
        else
          next
        end
      end.to_i
      ").to_i.should eq(1)
  end
end
