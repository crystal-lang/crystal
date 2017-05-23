require "spec"
require "logger"

describe "Logger" do
  it "logs messages" do
    IO.pipe do |r, w|
      logger = Logger.new(w)
      logger.debug "debug:skip"
      logger.info "info:show"

      logger.level = Logger::DEBUG
      logger.debug "debug:show"

      logger.level = Logger::WARN
      logger.debug "debug:skip:again"
      logger.info "info:skip"
      logger.error "error:show"

      r.gets.should match(/info:show/)
      r.gets.should match(/debug:show/)
      r.gets.should match(/error:show/)
    end
  end

  it "logs any object" do
    IO.pipe do |r, w|
      logger = Logger.new(w)
      logger.info 12345

      r.gets.should match(/12345/)
    end
  end

  it "formats message" do
    IO.pipe do |r, w|
      logger = Logger.new(w)
      logger.progname = "crystal"
      logger.warn "message"

      r.gets(chomp: false).should match(/W, \[.+? #\d+\]  WARN -- crystal: message\n/)
    end
  end

  it "uses custom formatter" do
    IO.pipe do |r, w|
      logger = Logger.new(w)
      logger.formatter = Logger::Formatter.new do |severity, datetime, progname, message, io|
        io << severity.to_s[0] << " " << progname << ": " << message
      end
      logger.warn "message", "prog"

      r.gets(chomp: false).should eq("W prog: message\n")
    end
  end

  it "yields message" do
    IO.pipe do |r, w|
      logger = Logger.new(w)
      logger.error { "message" }
      logger.unknown { "another message" }

      r.gets(chomp: false).should match(/ERROR -- : message\n/)
      r.gets(chomp: false).should match(/  ANY -- : another message\n/)
    end
  end

  it "yields message with progname" do
    IO.pipe do |r, w|
      logger = Logger.new(w)
      logger.error("crystal") { "message" }
      logger.unknown("shard") { "another message" }

      r.gets(chomp: false).should match(/ERROR -- crystal: message\n/)
      r.gets(chomp: false).should match(/  ANY -- shard: another message\n/)
    end
  end

  it "can create a logger with nil (#3065)" do
    logger = Logger.new(nil)
    logger.error("ouch")
  end

  it "doesn't yield to the block with nil" do
    a = 0
    logger = Logger.new(nil)
    logger.info { a = 1 }
    a.should eq(0)
  end

  it "closes" do
    IO.pipe do |r, w|
      Logger.new(w).close
      w.closed?.should be_true
    end
  end
end
