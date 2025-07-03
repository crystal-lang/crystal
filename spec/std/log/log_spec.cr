require "spec"
require "log"

private def s(value : Log::Severity)
  value
end

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

  describe Log::Severity do
    it "values are ordered" do
      s(:trace).should be < s(:debug)
      s(:debug).should be < s(:info)
      s(:info).should be < s(:notice)
      s(:notice).should be < s(:warn)
      s(:warn).should be < s(:error)
      s(:error).should be < s(:fatal)
      s(:fatal).should be < s(:none)
    end

    it "parses" do
      Log::Severity.parse("trace").should eq s(:trace)
      Log::Severity.parse("debug").should eq s(:debug)
      Log::Severity.parse("info").should eq s(:info)
      Log::Severity.parse("notice").should eq s(:notice)
      Log::Severity.parse("warn").should eq s(:warn)
      Log::Severity.parse("error").should eq s(:error)
      Log::Severity.parse("fatal").should eq s(:fatal)
      Log::Severity.parse("none").should eq s(:none)

      Log::Severity.parse("TRACE").should eq s(:trace)
      Log::Severity.parse("DEBUG").should eq s(:debug)
      Log::Severity.parse("INFO").should eq s(:info)
      Log::Severity.parse("NOTICE").should eq s(:notice)
      Log::Severity.parse("WARN").should eq s(:warn)
      Log::Severity.parse("ERROR").should eq s(:error)
      Log::Severity.parse("FATAL").should eq s(:fatal)
      Log::Severity.parse("NONE").should eq s(:none)
    end
  end

  it "filter messages to the backend above level only" do
    backend = Log::MemoryBackend.new
    log = Log.new("a", backend, :warn)

    log.trace { "trace message" }
    log.debug { "debug message" }
    log.info { "info message" }
    log.notice { "notice message" }
    log.warn { "warning message" }
    log.error { "error message" }
    log.fatal { "fatal message" }

    backend.entries.map { |e| {e.severity, e.message} }.should eq([
      {s(:warn), "warning message"},
      {s(:error), "error message"},
      {s(:fatal), "fatal message"},
    ])
  end

  it "level can be changed" do
    backend = Log::MemoryBackend.new
    log = Log.new("a", backend, :warn)

    log.level = :error

    log.trace { "trace message" }
    log.debug { "debug message" }
    log.info { "info message" }
    log.notice { "notice message" }
    log.warn { "warning message" }
    log.error { "error message" }
    log.fatal { "fatal message" }

    backend.entries.map { |e| {e.severity, e.message} }.should eq([
      {s(:error), "error message"},
      {s(:fatal), "fatal message"},
    ])
  end

  it "can attach exception to entries" do
    ex = Exception.new

    backend = Log::MemoryBackend.new
    log = Log.new("a", backend, :debug)

    log.trace(exception: ex) { "trace message" }
    log.debug(exception: ex) { "debug message" }
    log.info(exception: ex) { "info message" }
    log.notice(exception: ex) { "notice message" }
    log.warn(exception: ex) { "warning message" }
    log.error(exception: ex) { "error message" }
    log.fatal(exception: ex) { "fatal message" }

    backend.entries.all? { |e| e.exception == ex }.should be_true
  end

  it "can log exceptions without specifying a block" do
    backend = Log::MemoryBackend.new
    log = Log.new("a", backend, :warn)
    ex = Exception.new

    log.trace(exception: ex)
    log.debug(exception: ex)
    log.info(exception: ex)
    log.notice(exception: ex)
    log.warn(exception: ex)
    log.error(exception: ex)
    log.fatal(exception: ex)

    backend.entries.map { |e| {e.source, e.severity, e.message, e.data, e.exception} }.should eq([
      {"a", s(:warn), "", Log::Metadata.empty, ex},
      {"a", s(:error), "", Log::Metadata.empty, ex},
      {"a", s(:fatal), "", Log::Metadata.empty, ex},
    ])
  end

  it "contains the current context" do
    Log.context.set a: 1

    backend = Log::MemoryBackend.new
    log = Log.new("a", backend, :debug)

    log.info { "info message" }

    backend.entries.first.context.should eq(Log::Metadata.build({a: 1}))
  end

  it "context can be changed within the block, yet it's not restored" do
    Log.context.set a: 1

    backend = Log::MemoryBackend.new
    log = Log.new("a", backend, :debug)

    log.info { Log.context.set(b: 2); "info message" }

    backend.entries.first.context.should eq(Log::Metadata.build({a: 1, b: 2}))
    Log.context.metadata.should eq(Log::Metadata.build({a: 1, b: 2}))
  end

  it "context supports unsigned values" do
    Log.context.set a: 1_u32, b: 2_u64

    Log.context.metadata.should eq(Log::Metadata.build({a: 1_u32, b: 2_u64}))
  end

  describe "emitter dsl" do
    it "can be used with message" do
      backend = Log::MemoryBackend.new
      log = Log.new("a", backend, :debug)

      log.info &.emit("info message")

      entry = backend.entries.first
      entry.source.should eq("a")
      entry.severity.should eq(s(:info))
      entry.message.should eq("info message")
      entry.data.should eq(Log::Metadata.empty)
      entry.exception.should be_nil
    end

    it "can be used with message and exception" do
      backend = Log::MemoryBackend.new
      log = Log.new("a", backend, :debug)
      ex = Exception.new "the attached exception"

      log.debug exception: ex, &.emit("debug message")

      entry = backend.entries.first
      entry.source.should eq("a")
      entry.severity.should eq(s(:debug))
      entry.message.should eq("debug message")
      entry.data.should eq(Log::Metadata.empty)
      entry.exception.should eq(ex)
    end

    it "can be used with message and metadata explicitly" do
      backend = Log::MemoryBackend.new
      log = Log.new("a", backend, :notice)

      log.notice &.emit("notice message", m({a: 1}))

      entry = backend.entries.first
      entry.source.should eq("a")
      entry.severity.should eq(s(:notice))
      entry.message.should eq("notice message")
      entry.data.should eq(m({a: 1}))
      entry.exception.should be_nil
    end

    it "can be used with message and data via named arguments" do
      backend = Log::MemoryBackend.new
      log = Log.new("a", backend, :fatal)

      log.fatal &.emit("fatal message", a: 1)

      entry = backend.entries.first
      entry.source.should eq("a")
      entry.severity.should eq(s(:fatal))
      entry.message.should eq("fatal message")
      entry.data.should eq(m({a: 1}))
      entry.exception.should be_nil
    end

    it "can be used with message and data via named tuple" do
      backend = Log::MemoryBackend.new
      log = Log.new("a", backend, :fatal)

      log.fatal &.emit("fatal message", {a: 1})

      entry = backend.entries.first
      entry.source.should eq("a")
      entry.severity.should eq(s(:fatal))
      entry.message.should eq("fatal message")
      entry.data.should eq(m({a: 1}))
      entry.exception.should be_nil
    end

    it "can be used with exception" do
      backend = Log::MemoryBackend.new
      log = Log.new("a", backend, :fatal)
      ex = Exception.new "the attached exception"

      log.fatal exception: ex, &.emit("fatal message", a: 1)

      entry = backend.entries.first
      entry.source.should eq("a")
      entry.severity.should eq(s(:fatal))
      entry.message.should eq("fatal message")
      entry.data.should eq(m({a: 1}))
      entry.exception.should eq(ex)
    end

    it "can be used with data only explicitly" do
      backend = Log::MemoryBackend.new
      log = Log.new("a", backend, :notice)

      log.notice &.emit(m({a: 1}))

      entry = backend.entries.first
      entry.source.should eq("a")
      entry.severity.should eq(s(:notice))
      entry.message.should eq("")
      entry.data.should eq(m({a: 1}))
      entry.exception.should be_nil
    end

    it "can be used with data only via named arguments" do
      backend = Log::MemoryBackend.new
      log = Log.new("a", backend, :notice)

      log.notice &.emit(a: 1)

      entry = backend.entries.first
      entry.source.should eq("a")
      entry.severity.should eq(s(:notice))
      entry.message.should eq("")
      entry.data.should eq(m({a: 1}))
      entry.exception.should be_nil
    end

    it "can be used with data only via named tuple" do
      backend = Log::MemoryBackend.new
      log = Log.new("a", backend, :notice)

      log.notice &.emit(a: 1)

      entry = backend.entries.first
      entry.source.should eq("a")
      entry.severity.should eq(s(:notice))
      entry.message.should eq("")
      entry.data.should eq(m({a: 1}))
      entry.exception.should be_nil
    end

    it "does not emit when block returns nil" do
      backend = Log::MemoryBackend.new
      log = Log.new("a", backend, :notice)

      log.notice { nil }

      backend.entries.should be_empty
    end

    it "does emit when block returns nil but exception is provided" do
      backend = Log::MemoryBackend.new
      log = Log.new("a", backend, :notice)
      ex = Exception.new "the attached exception"

      log.notice(exception: ex) { nil }

      entry = backend.entries.first
      entry.source.should eq("a")
      entry.severity.should eq(s(:notice))
      entry.message.should eq("")
      entry.data.should eq(Log::Metadata.empty)
      entry.exception.should eq(ex)
    end
  end
end
