require "spec"
require "log"

private def m(value)
  Log::Metadata.build(value)
end

describe Log do
  before_each do
    Log.context.clear
  end

  after_each do
    Log.context.clear
  end

  describe ".context" do
    it "can be set and cleared" do
      Log.context.metadata.should eq(Log::Metadata.new)

      Log.context.set a: 1
      Log.context.metadata.should eq(m({a: 1}))

      Log.context.clear
      Log.context.metadata.should eq(Log::Metadata.new)
    end

    it "is extended by set" do
      Log.context.set a: 1
      Log.context.set b: 2
      Log.context.metadata.should eq(m({a: 1, b: 2}))
    end

    it "existing keys are overwritten by set" do
      Log.context.set a: 1, b: 1
      Log.context.set b: 2, c: 3
      Log.context.metadata.should eq(m({a: 1, b: 2, c: 3}))
    end

    it "is per fiber" do
      Log.context.set a: 1
      done = Channel(Nil).new

      spawn do
        Log.context.metadata.should eq(Log::Metadata.new)
        Log.context.set b: 2
        Log.context.metadata.should eq(m({b: 2}))

        done.receive
        done.receive
      end

      done.send nil
      Log.context.metadata.should eq(m({a: 1}))
      done.send nil
    end

    it "is assignable from a hash with symbol keys" do
      Log.context.set a: 1
      extra = {:b => 2}
      Log.context.set extra
      Log.context.metadata.should eq(m({a: 1, b: 2}))
    end

    it "is assignable from a named tuple" do
      Log.context.set a: 1
      extra = {b: 2}
      Log.context.set extra
      Log.context.metadata.should eq(m({a: 1, b: 2}))
    end
  end

  describe "#with_context" do
    it "with arguments restores context after the block" do
      Log.context.set a: 1
      log = Log.for("temp")

      log.with_context(b: 2) do
        log.context.set c: 3
        log.context.metadata.should eq(m({a: 1, b: 2, c: 3}))
      end

      log.context.metadata.should eq(m({a: 1}))
    end

    it "restores context after the block" do
      Log.context.set a: 1
      log = Log.for("temp")

      log.with_context do
        log.context.set b: 2
        log.context.metadata.should eq(m({a: 1, b: 2}))
      end

      log.context.metadata.should eq(m({a: 1}))
    end
  end

  describe ".with_context" do
    it "with arguments restores context after the block" do
      Log.context.set a: 1
      Log.with_context(b: 2) do
        Log.context.set c: 3
        Log.context.metadata.should eq(m({a: 1, b: 2, c: 3}))
      end

      Log.context.metadata.should eq(m({a: 1}))
    end

    it "restores context after the block" do
      Log.context.set a: 1

      Log.with_context do
        Log.context.set b: 2
        Log.context.metadata.should eq(m({a: 1, b: 2}))
      end

      Log.context.metadata.should eq(m({a: 1}))
    end

    it "assigns context via a hash with symbol keys" do
      Log.context.set a: 1
      extra = {:b => 2}
      Log.with_context(extra) do
        Log.context.set c: 3
        Log.context.metadata.should eq(m({a: 1, b: 2, c: 3}))
      end

      Log.context.metadata.should eq(m({a: 1}))
    end

    it "assigns context via a named tuple" do
      Log.context.set a: 1
      extra = {b: 2}
      Log.with_context(extra) do
        Log.context.set c: 3
        Log.context.metadata.should eq(m({a: 1, b: 2, c: 3}))
      end

      Log.context.metadata.should eq(m({a: 1}))
    end
  end
end
