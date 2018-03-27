require "spec"
require "logger"

describe Logger::IOAdapter do
  it "formats message" do
    IO.pipe do |r, w|
      adapter = Logger::IOAdapter.new(w)
      adapter.write(Logger::WARN, Time.now, "crystal", "message")

      r.gets(chomp: false).should match(/W, \[.+? #\d+\]  WARN -- crystal: message\n/)
    end
  end

  it "uses custom formatter" do
    IO.pipe do |r, w|
      adapter = Logger::IOAdapter.new(w)
      adapter.formatter = Logger::IOAdapter::Formatter.new do |severity, datetime, component, message, io|
        io << severity.to_s[0] << " " << component << ": " << message
      end
      adapter.write(Logger::WARN, Time.now, "prog", "message")

      r.gets(chomp: false).should eq("W prog: message\n")
    end
  end

  it "closes" do
    IO.pipe do |r, w|
      Logger::IOAdapter.new(w).close
      w.closed?.should be_true
    end
  end
end
