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
    abstract def emitters : Array(EmitterType)

    def log(entry : Entry)
      case ff = filter
      when Filter, Proc(Entry, Bool)
        return unless ff.call(entry)
      when Severity
        return unless entry.severity >= ff
      end
      emitters.each &.call(entry)
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
  getter emitters : Array(EmitterType)

  def initialize(@component, @filter, @emitters)
  end

  def self.new(component, filter, emitter : EmitterType)
    new(component, filter, [emitter] of EmitterType)
  end

  extend Base
  class_property component = ""
  class_property filter : FilterType?
  class_property emitters : Array(EmitterType) = [IOEmitter.new] of EmitterType

  def self.get(component)
    Logger.new(component.to_s, nil, Forwarder.new(self))
  end

  {% for level in Severity.constants %}
    {{ level }} = Severity::{{ level }}
  {% end %}
end
