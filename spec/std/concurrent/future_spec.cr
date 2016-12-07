require "spec"

class FutureTestClass
  def foo
    "foo"
  end
end

describe Concurrent::Future do
  describe "delay" do
    it "computes a value" do
      chan = Channel(Int32).new(1)

      d = delay(0.05) { chan.receive }
      d.delayed?.should be_true

      chan.send 3

      d.get.should eq(3)
      d.completed?.should be_true
    end

    it "cancels" do
      d = delay(1) { 42 }
      d.delayed?.should be_true

      d.cancel
      d.canceled?.should be_true

      expect_raises(Concurrent::CanceledError) { d.get }
    end

    it "raises" do
      d = delay(0.001) { raise IndexError.new("test error") }

      expect_raises(IndexError) { d.get }
      d.completed?.should be_true
    end

    it "create a delay delegate" do
      obj = FutureTestClass.new
      f = obj.delay(0.0001).foo
      f.delayed?.should be_true
      f.get.should eq("foo")
    end
  end

  describe "future" do
    it "computes a value" do
      chan = Channel(Int32).new(1)

      f = future { chan.receive }
      f.running?.should be_true

      chan.send 42
      Fiber.yield
      f.completed?.should be_true

      f.get.should eq(42)
      f.completed?.should be_true
    end

    it "can't cancel a completed computation" do
      f = future { 42 }
      f.running?.should be_true

      f.get.should eq(42)
      f.completed?.should be_true

      f.cancel
      f.canceled?.should be_false
    end

    it "raises" do
      f = future { raise IndexError.new("test error") }
      f.running?.should be_true

      Fiber.yield
      f.completed?.should be_true

      expect_raises(IndexError) { f.get }
      f.completed?.should be_true
    end

    it "create a future delegate" do
      obj = FutureTestClass.new
      f = obj.future.foo
      f.running?.should be_true
      f.get.should eq("foo")
    end
  end

  describe "lazy" do
    it "computes a value" do
      chan = Channel(Int32).new(1)

      f = lazy { chan.receive }
      f.idle?.should be_true

      chan.send 42
      Fiber.yield
      f.idle?.should be_true

      f.get.should eq(42)
      f.completed?.should be_true
    end

    it "cancels" do
      l = lazy { 42 }
      l.idle?.should be_true

      l.cancel
      l.canceled?.should be_true

      expect_raises(Concurrent::CanceledError) { l.get }
    end

    it "raises" do
      f = lazy { raise IndexError.new("test error") }
      f.idle?.should be_true

      Fiber.yield
      f.idle?.should be_true

      expect_raises(IndexError) { f.get }
      f.completed?.should be_true
    end

    it "create a lazy delegate" do
      obj = FutureTestClass.new
      f = obj.lazy.foo
      f.running?.should be_false
      f.get.should eq("foo")
    end
  end

  describe "spawn" do
    it "create a spawn delegate" do
      obj = FutureTestClass.new
      obj.spawn.foo
    end
  end
end
