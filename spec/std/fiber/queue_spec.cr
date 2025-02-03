require "../spec_helper"
require "fiber/queue"

describe Fiber::Queue do
  describe "#initialize" do
    it "creates an empty queue" do
      q = Fiber::Queue.new
      q.@head.should be_nil
      q.@tail.should be_nil
      q.size.should eq(0)
      q.empty?.should be_true
    end

    it "creates a filled queue" do
      f1 = Fiber.new(name: "f1") { }
      f2 = Fiber.new(name: "f2") { }
      f1.queue_next = f2
      f2.queue_next = nil

      q = Fiber::Queue.new(f2, f1, size: 2)
      q.@head.should be(f2)
      q.@tail.should be(f1)
      q.size.should eq(2)
      q.empty?.should be_false
    end
  end

  describe "#push" do
    it "to head" do
      q = Fiber::Queue.new
      f1 = Fiber.new(name: "f1") { }
      f2 = Fiber.new(name: "f2") { }
      f3 = Fiber.new(name: "f3") { }

      # simulate fibers previously added to other queues
      f1.queue_next = f3
      f2.queue_next = f1

      # push first fiber
      q.push(f1)
      q.@head.should be(f1)
      q.@tail.should be(f1)
      f1.queue_next.should be_nil
      q.size.should eq(1)

      # push second fiber
      q.push(f2)
      q.@head.should be(f2)
      q.@tail.should be(f1)
      f2.queue_next.should be(f1)
      f1.queue_next.should be_nil
      q.size.should eq(2)

      # push third fiber
      q.push(f3)
      q.@head.should be(f3)
      q.@tail.should be(f1)
      f3.queue_next.should be(f2)
      f2.queue_next.should be(f1)
      f1.queue_next.should be_nil
      q.size.should eq(3)
    end
  end

  describe "#bulk_unshift" do
    it "to empty queue" do
      # manually create a queue
      f1 = Fiber.new(name: "f1") { }
      f2 = Fiber.new(name: "f2") { }
      f3 = Fiber.new(name: "f3") { }
      f3.queue_next = f2
      f2.queue_next = f1
      f1.queue_next = nil
      q1 = Fiber::Queue.new(f3, f1, size: 3)

      # push in bulk
      q2 = Fiber::Queue.new(nil, nil, size: 0)
      q2.bulk_unshift(pointerof(q1))
      q2.@head.should be(f3)
      q2.@tail.should be(f1)
      q2.size.should eq(3)
    end

    it "to filled queue" do
      f1 = Fiber.new(name: "f1") { }
      f2 = Fiber.new(name: "f2") { }
      f3 = Fiber.new(name: "f3") { }
      f4 = Fiber.new(name: "f4") { }
      f5 = Fiber.new(name: "f5") { }

      # source queue
      f3.queue_next = f2
      f2.queue_next = f1
      f1.queue_next = nil
      q1 = Fiber::Queue.new(f3, f1, size: 3)

      # destination queue
      f5.queue_next = f4
      f4.queue_next = nil
      q2 = Fiber::Queue.new(f5, f4, size: 2)

      # push in bulk
      q2.bulk_unshift(pointerof(q1))
      q2.@head.should be(f5)
      q2.@tail.should be(f1)
      q2.size.should eq(5)

      f5.queue_next.should be(f4)
      f4.queue_next.should be(f3)
      f3.queue_next.should be(f2)
      f2.queue_next.should be(f1)
      f1.queue_next.should be(nil)
    end
  end

  describe "#pop" do
    it "from head" do
      f1 = Fiber.new(name: "f1") { }
      f2 = Fiber.new(name: "f2") { }
      f3 = Fiber.new(name: "f3") { }
      f3.queue_next = f2
      f2.queue_next = f1
      f1.queue_next = nil
      q = Fiber::Queue.new(f3, f1, size: 3)

      # removes third element
      q.pop.should be(f3)
      q.@head.should be(f2)
      q.@tail.should be(f1)
      q.size.should eq(2)

      # removes second element
      q.pop.should be(f2)
      q.@head.should be(f1)
      q.@tail.should be(f1)
      q.size.should eq(1)

      # removes first element
      q.pop.should be(f1)
      q.@head.should be_nil
      q.@tail.should be_nil
      q.size.should eq(0)

      # empty queue
      expect_raises(IndexError) { q.pop }
      q.size.should eq(0)
    end
  end

  describe "#pop?" do
    it "from head" do
      f1 = Fiber.new(name: "f1") { }
      f2 = Fiber.new(name: "f2") { }
      f3 = Fiber.new(name: "f3") { }
      f3.queue_next = f2
      f2.queue_next = f1
      f1.queue_next = nil
      q = Fiber::Queue.new(f3, f1, size: 3)

      # removes third element
      q.pop?.should be(f3)
      q.@head.should be(f2)
      q.@tail.should be(f1)
      q.size.should eq(2)

      # removes second element
      q.pop?.should be(f2)
      q.@head.should be(f1)
      q.@tail.should be(f1)
      q.size.should eq(1)

      # removes first element
      q.pop?.should be(f1)
      q.@head.should be_nil
      q.@tail.should be_nil
      q.size.should eq(0)

      # empty queue
      q.pop?.should be_nil
      q.size.should eq(0)
    end
  end
end
