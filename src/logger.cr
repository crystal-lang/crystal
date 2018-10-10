require "logger/entry"
require "logger/filter"
require "logger/emitter"
require "logger/severity"

class Logger
  alias FilterType = Filter | Severity | (Entry -> Bool)
  alias EmitterType = Emitter | (Entry -> Nil)

  module Base
    abstract def component : String
    abstract def filter : FilterType?
    abstract def emitter : EmitterType?

    def log(entry : Entry)
      case ff = filter
      when Filter, Proc(Entry, Bool)
        return unless ff.call(entry)
      when Severity
        return unless entry.severity >= ff
      end
      emitter.try &.call(entry)
    end

    {% for level in Severity.constants %}
      def {{ level.downcase.id }}(message, *, time = Time.now, line_number = __LINE__, filename = __FILE__)
        log Entry.new(message, Severity::{{ level }}, component, time, line_number, filename)
      end
    {% end %}
  end

  include Base
  getter component : String
  getter filter : FilterType?
  getter emitter : EmitterType?

  def initialize(@component, @filter, @emitter)
  end

  extend Base
  class_property component = ""
  class_property filter : FilterType?
  class_property emitter : EmitterType? = IOEmitter.new

  def self.get(component)
    Logger.new(component.to_s, nil, Forwarder.new(self))
  end

  {% for level in Severity.constants %}
    {{ level }} = Severity::{{ level }}
  {% end %}
end
