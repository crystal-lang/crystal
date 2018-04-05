require "spec"
require "logger"

describe Logger::IOAdapter do
  it "formats message" do
    IO.pipe do |r, w|
      adapter = Logger::IOAdapter.new(w, "")
      adapter.write(Logger::WARN, "message", Time.now, "crystal")
      adapter.write(Logger::WARN, "message", Time.now, "")

      r.gets(chomp: false).should match(/W, \[.+? #\d+\]  WARN \/ crystal: message\n/)
      r.gets(chomp: false).should match(/W, \[.+? #\d+\]  WARN: message\n/)
    end
  end

  it "formats message with program_name" do
    IO.pipe do |r, w|
      adapter = Logger::IOAdapter.new(w, "crystal")
      adapter.write(Logger::ERROR, "whoops", Time.now, "adapter")
      adapter.write(Logger::UNKNOWN, "uh oh", Time.now, "")

      r.gets(chomp: false).should match(/E, \[.+? #\d+\] ERROR -- crystal \/ adapter: whoops\n/)
      r.gets(chomp: false).should match(/A, \[.+? #\d+\]   ANY -- crystal: uh oh\n/)
    end
  end
end
