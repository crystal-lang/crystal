require "./emitter"

struct Logger
  alias FilterType = Filter | Severity | (Entry -> Bool)
  alias EmitterType = Emitter | (Entry -> Nil)

  class Dispatcher
    include Emitter

    property filter : FilterType?
    property emitters : Array(EmitterType)

    def initialize(@filter, @emitters)
    end

    def self.new(filter, emitter : EmitterType)
      new(filter, [emitter] of EmitterType)
    end

    def call(entry : Entry)
      case ff = filter
      when Filter, Proc(Entry, Bool)
        return unless ff.call(entry)
      when Severity
        return unless entry.severity >= ff
      end
      emitters.each &.call(entry)
    end

    def get(component) : Logger
      Logger.new(component.to_s, self)
    end
  end
end
