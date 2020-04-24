require "spec"
require "log"

private def s(value : Log::Severity)
  value
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
      s(:notice).should be < s(:warning)
      s(:warning).should be < s(:error)
      s(:error).should be < s(:fatal)
      s(:fatal).should be < s(:none)
    end

    it "parses" do
      Log::Severity.parse("trace").should eq s(:trace)
      Log::Severity.parse("debug").should eq s(:debug)
      Log::Severity.parse("info").should eq s(:info)
      Log::Severity.parse("notice").should eq s(:notice)
      Log::Severity.parse("warning").should eq s(:warning)
      Log::Severity.parse("error").should eq s(:error)
      Log::Severity.parse("fatal").should eq s(:fatal)
      Log::Severity.parse("none").should eq s(:none)

      Log::Severity.parse("TRACE").should eq s(:trace)
      Log::Severity.parse("DEBUG").should eq s(:debug)
      Log::Severity.parse("INFO").should eq s(:info)
      Log::Severity.parse("NOTICE").should eq s(:notice)
      Log::Severity.parse("WARNING").should eq s(:warning)
      Log::Severity.parse("ERROR").should eq s(:error)
      Log::Severity.parse("FATAL").should eq s(:fatal)
      Log::Severity.parse("NONE").should eq s(:none)
    end
  end

  it "filter messages to the backend above level only" do
    backend = Log::MemoryBackend.new
    log = Log.new("a", backend, :warning)

    log.trace { "trace message" }
    log.debug { "debug message" }
    log.info { "info message" }
    log.notice { "notice message" }
    log.warn { "warning message" }
    log.error { "error message" }
    log.fatal { "fatal message" }

    backend.entries.map { |e| {e.severity, e.message} }.should eq([
      {s(:warning), "warning message"},
      {s(:error), "error message"},
      {s(:fatal), "fatal message"},
    ])
  end

  it "level can be changed" do
    backend = Log::MemoryBackend.new
    log = Log.new("a", backend, :warning)

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

  it "contains the current context" do
    Log.context.set a: 1

    backend = Log::MemoryBackend.new
    log = Log.new("a", backend, :debug)

    log.info { "info message" }

    backend.entries.first.context.should eq(Log::Context.new({a: 1}))
  end

  it "context can be changed within the block and is restored" do
    Log.context.set a: 1

    backend = Log::MemoryBackend.new
    log = Log.new("a", backend, :debug)

    log.info { Log.context.set(b: 2); "info message" }

    backend.entries.first.context.should eq(Log::Context.new({a: 1, b: 2}))
    Log.context.should eq(Log::Context.new({a: 1}))
  end
end
