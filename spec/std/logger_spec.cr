require "spec"
require "logger"

class TestAdapter
  include Logger::Adapter
  getter messages = [] of String

  def write(severity, message, time, component)
    @messages << "#{severity} #{component} #{message}"
  end
end

describe Logger do
  it "forwards log messages" do
    adapter = TestAdapter.new
    handler = Logger::Handler.new(adapter)
    logger1 = Logger.new("foo", handler)
    logger2 = Logger.new("bar", handler)

    logger1.warn "one"
    logger2.debug "skip"
    logger2.info "two"
    logger1.warn "three"

    adapter.messages.shift.should eq("WARN foo one")
    adapter.messages.shift.should eq("INFO bar two")
    adapter.messages.shift.should eq("WARN foo three")
    adapter.messages.size.should eq 0
  end

  it "delegates level methods" do
    adapter = TestAdapter.new
    handler = Logger::Handler.new(adapter)
    logger1 = Logger.new("foo", handler)
    logger2 = Logger.new("foo::bar", handler)

    logger2.level?.should be_nil
    logger2.level!.should eq Logger::INFO
    logger2.debug?.should be_false
    logger2.debug "skip"

    logger1.level = Logger::DEBUG

    logger1.level?.should eq Logger::DEBUG
    logger1.level!.should eq Logger::DEBUG
    logger2.level?.should be_nil
    logger2.level!.should eq Logger::DEBUG
    logger2.debug?.should be_true
    logger2.debug "show"

    logger1.level = nil

    logger1.level?.should be_nil
    logger1.level!.should eq Logger::INFO
    logger2.level?.should be_nil
    logger2.level!.should eq Logger::INFO
    logger2.debug?.should be_false
    logger2.debug "show"

    adapter.messages.size.should eq 1
  end

  it "logs any object" do
    adapter = TestAdapter.new
    logger = Logger.new(Logger::Handler.new(adapter))
    logger.info 12345

    adapter.messages.shift.should eq("INFO  12345")
    adapter.messages.size.should eq 0
  end
end
