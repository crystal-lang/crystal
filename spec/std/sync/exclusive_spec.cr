require "./spec_helper"
require "sync/exclusive"

private class Foo
  INSTANCE = Foo.new
  class_getter foo = Sync::Exclusive(Int64 | Foo).new(0_i64)
  @value = 123
end

describe Sync::Exclusive do
  it "#lock(&)" do
    ary = [1, 2, 3, 4, 5]
    var = Sync::Exclusive.new(ary)
    var.lock { |val| val.should be(ary) }
  end

  it "#get" do
    ary = [1, 2, 3, 4, 5]
    var = Sync::Exclusive.new(ary)
    var.get.should be(ary)
  end

  it "#set" do
    ary1 = [1, 2, 3, 4, 5]
    ary2 = [4, 5, 8]

    var = Sync::Exclusive.new(ary1)
    var.set(ary2)
    var.get.should be(ary2)
  end

  it "#replace" do
    ary1 = [1, 2, 3, 4, 5]
    ary2 = [4, 5, 8]

    var = Sync::Exclusive.new(ary1)
    var.replace do |value|
      value.should be(ary1)
      ary2
    end
    var.get.should be(ary2)
  end

  it "#unsafe_get" do
    ary = [1, 2, 3, 4, 5]
    var = Sync::Exclusive.new(ary)
    var.unsafe_get.should be(ary)
  end

  it "#unsafe_set" do
    ary1 = [1, 2, 3, 4, 5]
    ary2 = [1, 2, 3, 4]

    var = Sync::Exclusive.new(ary1)
    var.unsafe_set(ary2)
    var.get.should be(ary2)
  end

  it "synchronizes" do
    var = Sync::Exclusive.new([] of Int32)
    wg = WaitGroup.new

    counter = Atomic(Int64).new(0)

    10.times do
      spawn(name: "exclusive-read") do
        100.times do
          var.lock do |value|
            value.each { counter.add(1, :relaxed) }
          end
          Fiber.yield
        end
      end
    end

    5.times do
      wg.spawn(name: "exclusive-write") do
        100.times do
          var.lock do |value|
            100.times { value << value.size }
          end
          Fiber.yield
        end
      end
    end

    4.times do
      wg.spawn(name: "set-replace") do
        50.times do |i|
          if i % 2 == 1
            var.set([] of Int32)
          else
            var.replace { |value| value[0...10] }
          end
          Fiber.yield
        end
      end

      wg.spawn(name: "dup-clone") do
        100.times do |i|
          if i % 2 == 0
            var.lock(&.dup)
          else
            var.lock(&.clone)
          end
          Fiber.yield
        end
      end
    end

    wg.wait

    counter.get(:relaxed).should be > 0
  end

  {% if flag?(:execution_context) %}
    # see https://github.com/crystal-lang/crystal/issues/15085
    it "synchronizes reads/writes of mixed unions" do
      ready = WaitGroup.new(1)
      running = true
      contexts = Array(Fiber::ExecutionContext::Isolated).new(3)

      contexts << Fiber::ExecutionContext::Isolated.new("set:foo") do
        ready.wait
        while running
          Foo.foo.set(Foo::INSTANCE)
        end
      end

      contexts << Fiber::ExecutionContext::Isolated.new("set:zero") do
        ready.wait
        while running
          Foo.foo.set(0_i64)
        end
      end

      contexts << Fiber::ExecutionContext::Isolated.new("get") do
        ready.wait
        while running
          Foo.foo.lock do |value|
            case value
            in Foo
              value.as(Void*).address.should eq(Foo::INSTANCE.as(Void*).address)
            in Int64
              value.should eq(0_i64)
            end
          end
        end
      end

      ready.done

      sleep 100.milliseconds
      running = false

      contexts.each(&.wait)
    end
  {% end %}
end
