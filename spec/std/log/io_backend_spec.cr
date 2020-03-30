require "spec"
require "log"

private def s(value : Log::Severity)
  value
end

private def io_logger(*, stdout : IO, config = nil, source : String = "", progname : String? = nil)
  builder = Log::Builder.new
  backend = Log::IOBackend.new
  backend.progname = progname if progname
  backend.io = stdout
  builder.bind("*", s(:info), backend)
  builder.for(source)
end

describe Log::IOBackend do
  it "logs messages" do
    IO.pipe do |r, w|
      logger = io_logger(stdout: w)
      logger.debug { "debug:skip" }
      logger.info { "info:show" }

      logger.level = s(:debug)
      logger.debug { "debug:show" }

      logger.level = s(:warning)
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

      r.gets.should match(/info:show -- {"foo" => "bar"}/)
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
      logger = io_logger(progname: "the-program", stdout: w, source: "db.pool")
      logger.warn { "message" }

      r.gets(chomp: false).should match(/W, \[.+? #\d+\] WARNING -- the-program:db.pool: message\n/)
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

  it "yields message" do
    IO.pipe do |r, w|
      logger = io_logger(stdout: w, progname: "prog", source: "db")
      logger.error { "message" }
      logger.fatal { "another message" }

      r.gets(chomp: false).should match(/ERROR -- prog:db: message\n/)
      r.gets(chomp: false).should match(/FATAL -- prog:db: another message\n/)
    end
  end
end
