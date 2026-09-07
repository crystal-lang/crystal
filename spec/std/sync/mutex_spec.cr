require "./spec_helper"
require "sync/mutex"

describe Sync::Mutex do
  Sync::Type.each do |type|
    describe type do
      it "locks and unlocks" do
        state = Atomic.new(0)
        m = Sync::Mutex.new(type)
        m.lock

        spawn do
          state.set(1)
          m.lock
          state.set(2)
        end

        Sync.eventually { state.get.should eq(1) }
        m.unlock
        Sync.eventually { state.get.should eq(2) }
      end

      unless type.unchecked?
        it "unlock raises when not locked" do
          m = Sync::Mutex.new(type)
          expect_raises(Sync::Error) { m.unlock }
        end

        it "unlock raises when another fiber tries to unlock" do
          m = Sync::Mutex.new(:reentrant)
          m.lock

          Sync.async do
            expect_raises(Sync::Error) { m.unlock }
          end
        end
      end

      it "synchronizes" do
        m = Sync::Mutex.new(type)
        counter = 0

        IO.pipe do |r, w|
          consumer = WaitGroup.new
          publishers = WaitGroup.new

          # no races when writing to pipe (concurrency)
          consumer.spawn do
            c = 0
            while line = r.gets
              line.to_i?.should eq(c += 1)
            end
          end

          # no races when incrementing counter (parallelism)
          100.times do |i|
            publishers.spawn do
              500.times do
                m.synchronize do
                  w.puts (counter += 1).to_s
                end
              end
            end
          end

          publishers.wait
          w.close
          counter.should eq(100 * 500)

          consumer.wait
        end
      end
    end
  end

  describe "unchecked" do
    it "hangs on deadlock" do
      m = Sync::Mutex.new(:unchecked)
      done = started = locked = false

      spawn do
        started = true

        m.lock
        locked = true

        m.lock # deadlock
        raise "ERROR: unreachable" unless done
      end

      Sync.eventually { started.should be_true }
      Sync.eventually { locked.should be_true }
      sleep 10.milliseconds

      # unlock the fiber (cleanup)
      done = true
      m.unlock
    end

    it "unlocks from other fiber" do
      m = Sync::Mutex.new(:unchecked)
      m.lock
      Sync.async { m.unlock }
    end
  end

  describe "checked" do
    it "raises on deadlock" do
      m = Sync::Mutex.new(:checked)
      m.lock
      expect_raises(Sync::Error::Deadlock) { m.lock }
    end
  end

  describe "reentrant" do
    it "re-locks" do
      m = Sync::Mutex.new(:reentrant)
      m.lock
      m.lock # nothing raised
    end

    it "unlocks as many times as it locked" do
      m = Sync::Mutex.new(:reentrant)
      100.times { m.lock }
      100.times { m.unlock }
      expect_raises(Sync::Error) { m.unlock }
    end
  end
end
