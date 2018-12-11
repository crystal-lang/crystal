require "spec"

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
  end

  describe "future" do
    it "computes a value" do
      chan = Channel::Unbuffered(Int32).new

      f = future { chan.receive }
      f.running?.should be_true

      chan.send 42
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
      # we rely on the channel to sync fibers:
      chan = Channel::Unbuffered(Int32).new

      f = future do
        chan.receive
        raise IndexError.new("test error")
      end
      f.running?.should be_true

      chan.send(0)
      f.completed?.should be_true

      expect_raises(IndexError) { f.get }
      f.completed?.should be_true
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
  end
end
