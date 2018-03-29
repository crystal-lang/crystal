require "spec"
require "logger"

describe Logger::IOAdapter do
  it "formats message" do
    IO.pipe do |r, w|
      adapter = Logger::IOAdapter.new(w, "")
      adapter.write(Logger::WARN, "message", Time.now, "crystal")

      r.gets(chomp: false).should match(/W, \[.+? #\d+\]  WARN \/ crystal: message\n/)
    end
  end

  it "formats message with program_name" do
    IO.pipe do |r, w|
      adapter = Logger::IOAdapter.new(w, "crystal")
      adapter.write(Logger::ERROR, "whoops", Time.now, "adapter")
      adapter.write(Logger::UNKNOWN, "uh oh", Time.now, "spec")

      r.gets(chomp: false).should match(/E, \[.+? #\d+\] ERROR -- crystal \/ adapter: whoops\n/)
      r.gets(chomp: false).should match(/A, \[.+? #\d+\]   ANY -- crystal \/ spec: uh oh\n/)
    end
  end

  it "closes" do
    IO.pipe do |r, w|
      Logger::IOAdapter.new(w).close
      w.closed?.should be_true
    end
  end
end
