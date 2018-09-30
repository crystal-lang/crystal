require "spec"
require "enumerator"

describe Enumerator do
  describe "initialize" do
    it "returns an instance of Enumerator" do
      instance = Enumerator(String).new { }
      instance.should be_a(Enumerator(String))
    end
  end

  describe "yielder" do
    it "accepts values of enumerator type" do
      enumerator = Enumerator(String).new do |yielder|
        yielder << "hello"
        yielder << "world"
      end

      enumerator.next.should eq("hello")
      enumerator.next.should eq("world")
    end

    it "allows to chain yielder calls" do
      enumerator = Enumerator(String).new do |yielder|
        yielder << "hello" << "world"
      end

      enumerator.next.should eq("hello")
      enumerator.next.should eq("world")
    end
  end

  describe "next" do
    it "returns the values in the order they were yielded" do
      enumerator = Enumerator(String?).new do |yielder|
        yielder << "hello"
        yielder << nil
        yielder << "world"
      end

      enumerator.next.should eq("hello")
      enumerator.next.should be_nil
      enumerator.next.should eq("world")
      enumerator.next.should be_a(Iterator::Stop)
    end

    it "works when the type is Nil" do
      enumerator = Enumerator(Nil).new do |yielder|
        yielder << nil
        yielder << nil
      end

      enumerator.next.should be_nil
      enumerator.next.should be_nil
      enumerator.next.should be_a(Iterator::Stop)
    end

    it "starts the yielder block at the first call" do
      started = false
      enumerator = Enumerator(Int32).new do |y|
        started = true
        y << 1
      end

      started.should be_false
      enumerator.next.should eq(1)
      started.should be_true
    end

    it "cooperates with other fibers outside the enumerator" do
      enumerator = Enumerator(Int32).new do |y|
        y << 1
      end

      value = 0
      spawn do
        value = enumerator.next
      end

      Fiber.yield

      value.should eq(1)
    end

    it "cooperates with other fibers inside the enumerator" do
      enumerator = Enumerator(Int32).new do |y|
        spawn do
          y << 1
        end
        Fiber.yield
        y << 2
      end

      enumerator.next.should eq(1)
      enumerator.next.should eq(2)
    end
  end

  describe "peek" do
    it "peeks at the next value without affecting next" do
      enumerator = Enumerator(String).new do |yielder|
        yielder << "hello"
        yielder << "world"
      end

      enumerator.peek.should eq("hello")
      enumerator.peek.should eq("hello")
      enumerator.next.should eq("hello")
      enumerator.peek.should eq("world")
      enumerator.peek.should eq("world")
      enumerator.next.should eq("world")
      enumerator.peek.should be_a(Iterator::Stop)
      enumerator.next.should be_a(Iterator::Stop)
    end

    it "does not affect rewind" do
      enumerator = Enumerator(String).new do |yielder|
        yielder << "hello"
        yielder << "world"
      end

      enumerator.next.should eq("hello")
      enumerator.peek.should eq("world")
      enumerator.rewind
      enumerator.peek.should eq("hello")
      enumerator.next.should eq("hello")
    end

    it "works when the type is Nil" do
      enumerator = Enumerator(Nil).new do |yielder|
        yielder << nil
        yielder << nil
      end

      enumerator.peek.should be_nil
      enumerator.next.should be_nil
      enumerator.peek.should be_nil
      enumerator.next.should be_nil
      enumerator.peek.should be_a(Iterator::Stop)
      enumerator.next.should be_a(Iterator::Stop)
    end
  end

  describe "each" do
    it "iterates the yielded values" do
      enumerator = Enumerator(String).new do |yielder|
        yielder << "hello"
        yielder << "world"
      end

      values = [] of String
      enumerator.each { |value| values << value }
      values.should eq(["hello", "world"])
    end
  end

  describe "rewind" do
    it "rewinds the iterator after full iteration" do
      enumerator = Enumerator(String).new do |yielder|
        yielder << "hello"
        yielder << "world"
      end

      enumerator.next.should eq("hello")
      enumerator.next.should eq("world")
      enumerator.next.should be_a(Iterator::Stop)

      enumerator.rewind.should be_a(Enumerator(String))

      enumerator.next.should eq("hello")
    end

    it "rewinds the iterator after partial iteration" do
      enumerator = Enumerator(String).new do |yielder|
        yielder << "hello"
        yielder << "world"
      end
      enumerator.next.should eq("hello")

      enumerator.rewind.should be_a(Enumerator(String))
      enumerator.next.should eq("hello")
    end

    it "can be called before the first iteration" do
      enumerator = Enumerator(String).new do |yielder|
        yielder << "hello"
        yielder << "world"
      end

      enumerator.rewind.should be_a(Enumerator(String))

      enumerator.next.should eq("hello")
      enumerator.next.should eq("world")
      enumerator.next.should be_a(Iterator::Stop)
    end

    it "can be rewound multiple times" do
      enumerator = Enumerator(String).new do |yielder|
        yielder << "hello"
        yielder << "world"
      end

      enumerator.next.should eq("hello")
      enumerator.next.should eq("world")
      enumerator.next.should be_a(Iterator::Stop)

      enumerator.rewind.should be_a(Enumerator(String))
      enumerator.rewind.should be_a(Enumerator(String))

      enumerator.next.should eq("hello")
    end
  end

  describe "Fibonacci enumerator" do
    it "generates the first 10 numbers in the Fibonacci sequence" do
      # Make sure example from the Enumerator docs works.
      fib = Enumerator(Int32).new do |y|
        a = b = 1
        loop do
          y << a
          a, b = b, a + b
        end
      end

      fib.first(10).to_a.should eq([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])
    end
  end
end
