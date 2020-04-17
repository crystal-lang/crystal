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

private def assert_logged(expected : Regex, & : Log -> Nil)
  IO.pipe do |r, w|
    logger = io_logger(stdout: w)

    yield logger

    r.gets.should match expected
  end
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

  describe "logging context" do
    it "via Log.context" do
      assert_logged(/info:show -- {"foo" => "bar"}/) do |logger|
        Log.with_context do
          Log.context.set foo: "bar"
          logger.info { "info:show" }
        end
      end
    end

    describe Hash do
      it "directly" do
        assert_logged(/info:show -- {"foo" => "bar"}/) do |logger|
          logger.info context: {"foo" => "bar"} { "info:show" }
        end
      end

      it "with mixed type keys" do
        assert_logged(/info:show -- {"foo" => "bar", "1" => 17, "true" => false}/) do |logger|
          logger.info context: {"foo" => "bar", 1 => 17, true => false} { "info:show" }
        end
      end

      it Exception do
        assert_logged(/info:show -- {"foo" => "bar", "1" => 17, "true" => false}/) do |logger|
          logger.info exception: Exception.new("ERR"), context: {"foo" => "bar", 1 => 17, true => false} { "info:show" }
        end
      end
    end

    describe NamedTuple do
      it "directly" do
        assert_logged(/info:show -- {"foo" => "bar"}/) do |logger|
          logger.info context: {foo: "bar"} { "info:show" }
        end
      end

      it Exception do
        assert_logged(/info:show -- {"foo" => "bar"}/) do |logger|
          logger.info exception: Exception.new("ERR"), context: {foo: "bar"} { "info:show" }
        end
      end
    end

    it "with named args" do
      assert_logged(/info:show -- {"foo" => "bar"}/) do |logger|
        logger.info(foo: "bar") { "info:show" }
      end
    end

    it Exception do
      assert_logged(/info:show --/) do |logger|
        logger.info(exception: Exception.new("ERR")) { "info:show" }
      end
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
