require "./entry"

class Logger
  module Emitter
    abstract def call(entry : Entry) : Nil
  end

  class IOEmitter
    include Emitter

    DEFAULT_FORMATTER = ->(io : IO, entry : Entry) do
      io << entry.time << ' ' << entry.severity.to_s.ljust(5) << " ::"
      io << entry.component << " " << entry.message << '\n'
      return nil
    end

    def initialize(@io : IO = STDOUT, @formatter : Proc(IO, Entry, Nil) = DEFAULT_FORMATTER)
    end

    def call(entry : Entry) : Nil
      @formatter.call(@io, entry)
    end
  end

  class Forwarder
    include Emitter

    getter dest : Logger

    def initialize(@dest)
    end

    def call(entry : Entry)
      dest.log(entry)
    end
  end
end
