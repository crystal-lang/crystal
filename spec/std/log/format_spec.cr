require "spec"
require "log"

class Log
  describe ShortFormat do
    it "formats an entry" do
      entry = Entry.new("source", :info, "message", Log::Metadata.empty, nil)
      io = IO::Memory.new
      ShortFormat.format(entry, io)
      io.to_s.should match(/^[\d\-.:TZ]+\s* INFO - source: message$/)
    end

    it "hides the source if empty" do
      entry = Entry.new("", :info, "message", Log::Metadata.empty, nil)
      io = IO::Memory.new
      ShortFormat.format(entry, io)
      io.to_s.should match(/^[\d\-.:TZ]+\s* INFO - message$/)
    end

    it "shows the context data" do
      entry = Log.with_context do
        Log.context.set a: 1, b: 2
        Entry.new("source", :info, "message", Log::Metadata.empty, nil)
      end
      io = IO::Memory.new
      ShortFormat.format(entry, io)
      io.to_s.should match(/^[\d\-.:TZ]+\s* INFO - source: message -- a: 1, b: 2$/)
    end

    it "shows context and entry data" do
      entry = Log.with_context do
        Log.context.set a: 1, b: 2
        Entry.new("source", :info, "message", Log::Metadata.build({c: 3, d: 4}), nil)
      end
      io = IO::Memory.new
      ShortFormat.format(entry, io)
      io.to_s.should match(/^[\d\-.:TZ]+\s* INFO - source: message -- c: 3, d: 4 -- a: 1, b: 2$/)
    end

    it "appends the exception" do
      exception = expect_raises(Exception) { raise "foo" }
      entry = Entry.new("source", :error, "message", Log::Metadata.empty, exception)
      io = IO::Memory.new
      ShortFormat.format(entry, io)
      io.rewind
      io.gets.should match(/^[\d\-.:TZ]+\s* ERROR - source: message$/)
      io.gets_to_end.should eq(exception.inspect_with_backtrace)
    end
  end

  describe ProcFormatter do
    it "formats" do
      entry = Entry.new("source", :info, "message", Log::Metadata.empty, nil)
      io = IO::Memory.new
      formatter = Formatter.new do |entry, io|
        io << "[" << entry.message << "]"
      end
      formatter.format(entry, io)
      io.to_s.should eq("[message]")
    end
  end

  define_formatter TestFormatter, "#{severity} #{source(before: '[', after: "] ")}#{progname} #{message}" \
                                  "#{context(before: " (", after: ')')}#{exception}"
  Log.progname = "test"

  describe TestFormatter do
    it "formats" do
      exception = expect_raises(Exception) { raise "foo" }
      entry = Log.with_context do
        Log.context.set a: 1, b: 2
        Entry.new("source", :info, "message", Log::Metadata.empty, nil)
      end
      io = IO::Memory.new
      TestFormatter.format(entry, io)
      io.puts
      TestFormatter.format(Entry.new("", :info, "message", Log::Metadata.empty, nil), io)
      io.puts
      TestFormatter.format(Entry.new("source", :error, "Oh, no", Log::Metadata.empty, exception), io)
      io.rewind

      io.gets.should eq("  INFO [source] test message (a: 1, b: 2)")
      io.gets.should eq("  INFO test message")
      io.gets.should eq(" ERROR [source] test Oh, no")
      io.gets_to_end.should eq(exception.inspect_with_backtrace)
    end
  end
end
