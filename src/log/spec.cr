require "spec/dsl"

class Log
  # Returns and yields an `EntriesChecker` that allows checking specific log entries
  # were emitted.
  #
  # This capture will even work if there are currently no backends configured, effectively
  # adding a temporary backend.
  #
  # ```
  # require "spec"
  # require "log"
  # require "log/spec"
  #
  # Log.setup(:none)
  #
  # def greet(name)
  #   Log.info { "Greeting #{name}" }
  # end
  #
  # it "greets" do
  #   Log.capture do |logs|
  #     greet("Harry")
  #     greet("Hermione")
  #     greet("Ron")
  #
  #     logs.check(:info, /greeting harry/i)
  #     logs.next(:info, /greeting hermione/i)
  #   end
  # end
  # ```
  #
  # By default logs of all sources and severities  will be captured.
  #
  # Use *level* to only capture of the given severity or above.
  #
  # Use *source* to narrow which source are captured. Values that represent single pattern like `http.*` are allowed.
  #
  # The `EntriesChecker` will hold a list of emitted entries.
  #
  # `EntriesChecker#check` will find the next entry which matches the level and message.
  # `EntriesChecker#next` will validate that the following entry in the list matches the given level and message.
  # `EntriesChecker#clear` will clear the emitted and captured entries.
  #
  # With these methods it is possible to express expected traces in either a strict or loose way, while checking ordering.
  #
  # `EntriesChecker#entry` returns the last matched `Entry`. Useful to check additional entry properties other than the message.
  #
  # `EntriesChecker#empty` validates there are no pending entries to match.
  #
  # Using the yielded `EntriesChecker` allows clearing the entries between statements.
  #
  # Invocations can be nested in order to capture each source in their own `EntriesChecker`.
  #
  def self.capture(source : String = "*", level : Severity = Log::Severity::Trace, *, builder = Log.builder, &)
    mem_backend = Log::MemoryBackend.new
    builder.bind(source, level, mem_backend)
    begin
      dsl = Log::EntriesChecker.new(mem_backend.entries)
      yield dsl
      dsl
    ensure
      builder.unbind(source, level, mem_backend)
    end
  end

  # :ditto:
  def self.capture(level : Log::Severity = Log::Severity::Trace,
                   *, builder : Log::Builder = Log.builder, &)
    capture("*", level, builder: builder) do |dsl|
      yield dsl
    end
  end

  # DSL for `Log.capture`
  class EntriesChecker
    def initialize(@entries : Array(Log::Entry))
    end

    # Returns the last entry matched by `#check` or `#next`
    getter! entry : Entry

    # :nodoc:
    def check(description, file = __FILE__, line = __LINE__, & : Entry -> Bool) : self
      fail("No entries found, expected #{description}", file, line) if @entries.empty?
      original_size = @entries.size

      while entry = @entries.shift?
        matches = yield entry
        if matches
          @entry = entry
          return self
        end
      end

      fail("No matching entries found, expected #{description}, skipped (#{original_size})", file, line)
    end

    # Validates that at some point the indicated entry was emitted
    def check(level : Severity, message : String, file = __FILE__, line = __LINE__) : self
      self.check("#{level} with #{message.inspect}", file, line) { |e| e.severity == level && e.message == message }
    end

    # :ditto:
    def check(level : Severity, pattern : Regex, file = __FILE__, line = __LINE__, *, options : Regex::MatchOptions = Regex::MatchOptions::None) : self
      self.check("#{level} matching #{pattern.inspect}", file, line) { |e| e.severity == level && e.message.matches?(pattern, options: options) }
    end

    # :nodoc:
    def next(description, file = __FILE__, line = __LINE__, & : Entry -> Bool) : self
      if entry = @entries.shift?
        matches = yield entry
        if matches
          @entry = entry
          self
        else
          fail("No matching entries found, expected #{description}, but got #{entry.severity} with #{entry.message.inspect}", file, line)
        end
      else
        fail("No entries found, expected #{description}", file, line)
      end
    end

    # Validates that the indicated entry was the next one to be emitted
    def next(level : Severity, message : String, file = __FILE__, line = __LINE__) : self
      self.next("#{level} with #{message.inspect}", file, line) { |e| e.severity == level && e.message == message }
    end

    # :ditto:
    def next(level : Severity, pattern : Regex, file = __FILE__, line = __LINE__, *, options : Regex::MatchOptions = Regex::MatchOptions::None) : self
      self.next("#{level} matching #{pattern.inspect}", file, line) { |e| e.severity == level && e.message.matches?(pattern, options: options) }
    end

    # Clears the emitted entries so far
    def clear
      @entry = nil
      @entries.clear
      self
    end

    # Validates that there are no outstanding entries
    def empty(file = __FILE__, line = __LINE__)
      @entry = nil
      if first = @entries.first?
        fail("Expected no entries, but got #{first.severity} with #{first.message.inspect} in a total of #{@entries.size} entries", file, line)
      else
        self
      end
    end
  end
end
