require "spec"
require "log"

private def m(source : String, pattern : String) : Bool
  Log::Builder.matches(source, pattern)
end

private def s(value : Log::Severity)
  value
end

describe Log::Builder do
  it "creates a log with nil backend" do
    builder = Log::Builder.new

    log = builder.for("db")

    log.backend.should be_nil
    log.source.should eq("db")
    log.level.should eq(s(:none))
  end

  it "creates a log with single backend" do
    builder = Log::Builder.new
    builder.bind("db", :fatal, Log::MemoryBackend.new)

    log = builder.for("db")

    log.backend.should be_a(Log::MemoryBackend)
    log.source.should eq("db")
    log.level.should eq(s(:fatal))
  end

  it "creates a log with broadcast backend" do
    builder = Log::Builder.new
    a = Log::MemoryBackend.new
    b = Log::MemoryBackend.new
    builder.bind("db", :fatal, a)
    builder.bind("db", :info, b)

    log = builder.for("db")

    backend = log.backend.should be_a(Log::BroadcastBackend)
    backend.@backends[a].should eq(s(:fatal))
    backend.@backends[b].should eq(s(:info))
    log.source.should eq("db")
    log.level.should eq(s(:info))
  end

  it "does not alter user-provided broadcast backend" do
    builder = Log::Builder.new
    a = Log::MemoryBackend.new
    b = Log::MemoryBackend.new

    broadcast = Log::BroadcastBackend.new
    broadcast.append(a, :fatal)
    previous_backends = broadcast.@backends.dup

    builder.bind("db", :trace, broadcast)
    builder.bind("db", :info, b)

    log = builder.for("db")

    backend = log.backend.should be_a(Log::BroadcastBackend)
    backend.should_not be broadcast
    broadcast.@backends.should eq(previous_backends)
  end

  it "creates a log for broadcast backend" do
    builder = Log::Builder.new
    a = Log::MemoryBackend.new
    b = Log::MemoryBackend.new

    broadcast = Log::BroadcastBackend.new
    broadcast.append(a, :fatal)

    builder.bind("db", :trace, broadcast)
    builder.bind("db", :info, b)

    log = builder.for("db")

    backend = log.backend.should be_a(Log::BroadcastBackend)
    backend.@backends.should eq({broadcast => s(:trace), b => s(:info)})
    log.source.should eq("db")
    log.level.should eq(s(:trace))
  end

  it "creates a log for same broadcast backend added multiple times" do
    builder = Log::Builder.new
    a = Log::MemoryBackend.new

    broadcast = Log::BroadcastBackend.new
    broadcast.append(a, :fatal)

    builder.bind("db", :trace, broadcast)
    builder.bind("db", :info, broadcast)

    log = builder.for("db")

    backend = log.backend.should be_a(Log::BroadcastBackend)
    backend.should be(broadcast)
    backend.@backends.should eq({a => s(:fatal)})
    log.source.should eq("db")
    log.level.should eq(s(:info))
  end

  it "uses last level for a source x backend" do
    builder = Log::Builder.new
    a = Log::MemoryBackend.new
    b = Log::MemoryBackend.new
    builder.bind("db", :fatal, a)
    builder.bind("db", :info, b)
    builder.bind("db", :debug, a)

    log = builder.for("db")

    backend = log.backend.should be_a(Log::BroadcastBackend)
    backend.@backends[a].should eq(s(:debug))
    backend.@backends[b].should eq(s(:info))
    log.source.should eq("db")
    log.level.should eq(s(:debug))
  end

  it "uses last level for a source x backend (single-backend)" do
    builder = Log::Builder.new
    a = Log::MemoryBackend.new
    builder.bind("db", :fatal, a)
    builder.bind("db.*", :debug, a)

    log = builder.for("db")

    log.backend.should eq(a)
    log.source.should eq("db")
    log.level.should eq(s(:debug))
  end

  it "returns log with backend if pattern matches" do
    builder = Log::Builder.new
    a = Log::MemoryBackend.new
    builder.bind("db.*", :fatal, a)

    log = builder.for("db.pool")

    log.backend.should eq(a)
    log.source.should eq("db.pool")
    log.level.should eq(s(:fatal))
  end

  it "returns log without backend if pattern does not match" do
    builder = Log::Builder.new
    a = Log::MemoryBackend.new
    builder.bind("db.*", :fatal, a)

    log = builder.for("")

    log.backend.should be_nil
    log.source.should eq("")
    log.level.should eq(s(:none))
  end

  it "can turn off parent and allow child source" do
    builder = Log::Builder.new
    a = Log::MemoryBackend.new
    builder.bind("*", :fatal, a)
    builder.bind("db.*", :warn, a)
    builder.bind("db", :error, a)
    builder.bind("db.pool", :none, a)

    builder.for("").level.should eq(s(:fatal))
    builder.for("db").level.should eq(s(:error))
    builder.for("db.query").level.should eq(s(:warn))
    builder.for("db.pool").level.should eq(s(:none))
  end

  it "returns same instance" do
    builder = Log::Builder.new

    builder.for("").should be(builder.for(""))
    builder.for("db").should be(builder.for("db"))
    builder.for("").should_not be(builder.for("db"))
  end

  it "can reconfigures existing logs" do
    builder = Log::Builder.new
    log = builder.for("")
    log.backend.should be_nil
    log.level.should eq(s(:none))

    a = Log::MemoryBackend.new
    builder.bind("*", :warn, a)

    log.backend.should be(a)
    log.level.should eq(s(:warn))
  end

  it "removes all logs backends on .clear" do
    builder = Log::Builder.new
    builder.bind("*", :fatal, Log::MemoryBackend.new)
    log = builder.for("")
    log_db = builder.for("db")

    log.backend.should_not be_nil
    log.level.should eq(s(:fatal))
    log_db.backend.should_not be_nil
    log_db.level.should eq(s(:fatal))

    builder.clear

    log.backend.should be_nil
    log.level.should eq(s(:none))
    log_db.backend.should be_nil
    log_db.level.should eq(s(:none))
  end

  it "should allow collection of unreferenced logs" do
    builder = Log::Builder.new
    10.times do |i|
      builder.for("a.#{i}")
    end
    original_size = builder.@logs.values.size
    original_size.should be >= 10
    GC.collect
    builder.@logs.values.count(&.value.nil?).should be > 0

    # force a cleanup
    builder.bind("a.9", :info, Log::MemoryBackend.new)
    builder.@logs.values.size.should be < original_size
  end

  it "should allow recreation of deallocated logs" do
    builder = Log::Builder.new
    10.times do |i|
      builder.for("a.#{i}")
    end
    GC.collect
    10.times do |i|
      builder.for("a.#{i}")
    end
    builder.@logs.values.size.should eq(10)
    builder.@logs.values.count(&.value.nil?).should eq(0)
  end

  describe ".matches" do
    it "on top-level" do
      m("", "").should be_true
      m("", "db").should be_false
      m("", "db.pool").should be_false
      m("", "*").should be_true
    end

    it "on first level" do
      m("db", "").should be_false
      m("db", "db").should be_true
      m("db", "*").should be_true
      m("db", "db.*").should be_true
      m("db", "db.pool").should be_false
      m("db", "other").should be_false
      m("db", "other.*").should be_false
    end

    it "on second level" do
      m("db.pool", "").should be_false
      m("db.pool", "db").should be_false
      m("db.pool", "*").should be_true
      m("db.pool", "db.*").should be_true
      m("db.pool", "db.pool").should be_true
      m("db.pool", "other").should be_false
      m("db.pool", "other.*").should be_false
    end

    it "on third level" do
      m("db.pool.foo", "db.*").should be_true
      m("db.pool.foo", "db.pool.*").should be_true
      m("db.pool.foo", "db.pool").should be_false
    end

    it "avoids prefix collision" do
      m("dbnot", "db.*").should be_false
    end
  end
end
