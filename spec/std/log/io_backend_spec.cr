require "../spec_helper"
require "log"

private def s(value : Log::Severity)
  value
end

private def io_logger(*, stdout : IO, config = nil, source : String = "")
  builder = Log::Builder.new
  backend = Log::IOBackend.new
  backend.io = stdout
  builder.bind("*", s(:info), backend)
  builder.for(source)
end

describe Log::IOBackend do
  it "creates with defaults" do
    backend = Log::IOBackend.new
    backend.io.should eq(STDOUT)
    backend.formatter.should eq(Log::ShortFormat)
    backend.dispatcher.should be_a(Log::AsyncDispatcher)
  end

  it "logs messages" do
    IO.pipe do |r, w|
      logger = io_logger(stdout: w)
      logger.debug { "debug:skip" }
      logger.info { "info:show" }

      logger.level = s(:debug)
      logger.debug { "debug:show" }

      logger.level = s(:warn)
      logger.debug { "debug:skip:again" }
      logger.info { "info:skip" }
      logger.error { "error:show" }

      r.gets.should match(/info:show/)
      r.gets.should match(/debug:show/)
      r.gets.should match(/error:show/)
    end
  end

  it "logs context" do
    IO.pipe do |r, w|
      logger = io_logger(stdout: w)
      Log.context.clear
      Log.with_context do
        Log.context.set foo: "bar"
        logger.info { "info:show" }
      end

      r.gets.should match(/info:show -- foo: "bar"/)
    end
  end

  it "logs any object" do
    IO.pipe do |r, w|
      logger = io_logger(stdout: w)
      logger.info { 12345 }

      r.gets.should match(/12345/)
    end
  end

  it "formats message" do
    IO.pipe do |r, w|
      logger = io_logger(stdout: w, source: "db.pool")
      logger.warn { "message" }

      r.gets(chomp: false).should match(/.+? WARN - db.pool: message\n/)
    end
  end

  it "uses custom formatter" do
    IO.pipe do |r, w|
      logger = io_logger(stdout: w)
      logger.backend.as(Log::IOBackend).formatter = Log::Formatter.new do |entry, io|
        io << entry.severity.to_s[0].upcase << ": " << entry.message
      end
      logger.warn { "message" }

      r.gets(chomp: false).should eq("W: message\n")
    end
  end

  it "allows setting formatter in initializer" do
    formatter = Log::Formatter.new { |_entry, io| io }
    backend = Log::IOBackend.new(formatter: formatter)

    log = Log.new("foo", backend, :info)

    log.backend.should eq(backend)
  end

  it "yields message" do
    IO.pipe do |r, w|
      logger = io_logger(stdout: w, source: "db")
      logger.error { "message" }
      logger.fatal { "another message" }

      r.gets(chomp: false).should match(/ERROR - db: message\n/)
      r.gets(chomp: false).should match(/FATAL - db: another message\n/)
    end
  end
end
