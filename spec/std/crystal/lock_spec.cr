require "crystal/lock"
require "../sync/spec_helper"

describe Crystal::Lock do
  it "#lock raises on deadlock" do
    lock = Crystal::Lock.new
    called = 0

    lock.lock do
      called = 1

      expect_raises(Sync::Error::Deadlock) do
        lock.lock { called = 2 }
      end
    end

    called.should eq(1)
  end

  it "synchronizes" do
    lock = Crystal::Lock.new
    wg = WaitGroup.new

    ary = [] of Int32
    counter = Atomic(Int64).new(0)

    # readers can run concurrently, but are mutually exclusive to writers (the
    # array can be safely read from):

    10.times do
      spawn(name: "reader") do
        100.times do
          lock.rlock do
            ary.each { counter.add(1) }
          end
          Fiber.yield
        end
      end
    end

    # writers are mutually exclusive: they can safely mutate the array

    5.times do
      wg.spawn(name: "writer:increment") do
        100.times do
          lock.lock { 100.times { ary << ary.size } }
          Fiber.yield
        end
      end
    end

    4.times do
      wg.spawn(name: "writer:decrement") do
        100.times do
          lock.lock { 100.times { ary.pop? } }
          Fiber.yield
        end
      end
    end

    wg.wait

    ary.should eq((0..(ary.size - 1)).to_a)
    counter.lazy_get.should be > 0
  end
end
