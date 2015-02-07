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

  it "formats message" do
    IO.pipe do |r, w|
      logger = Logger.new(w)
      logger.progname = "crystal"
      logger.warn "message"

      r.gets.should match(/W, \[.+? #\d+\]  WARN -- crystal: message\n/)
    end
  end

  it "uses custom formatter" do
    IO.pipe do |r, w|
      logger = Logger.new(w)
      logger.formatter = ->(severity : String, datetime : Time, progname : String, message : String) {
        "#{severity[0]} #{progname}: #{message}"
      }
      logger.warn "message", "prog"

      r.gets.should match(/W prog: message\n/)
    end
  end
end
