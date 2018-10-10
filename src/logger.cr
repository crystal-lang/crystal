require "logger/entry"
require "logger/filter"
require "logger/emitter"
require "logger/severity"

class Logger
  alias FilterType = Filter | Severity | (Entry -> Bool)
  alias EmitterType = Emitter | (Entry -> Nil)

  property component : String
  property filter : FilterType?
  property emitters : Array(EmitterType)

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
    {% unless level == "SILENT" %}
      def {{ level.downcase.id }}(message, *, time = Time.now, line_number = __LINE__, filename = __FILE__)
        log Entry.new(message, Severity::{{ level }}, component, time, line_number, filename)
      end
    {% end %}
  {% end %}

  def get(component) : Logger
    Logger.new(component.to_s, nil, Forwarder.new(self))
  end

  def initialize(@component, @filter, @emitters)
  end

  def self.new(component, filter, emitter : EmitterType)
    new(component, filter, [emitter] of EmitterType)
  end

  ROOT = new("", nil, IOEmitter.new)

  def self.get(component) : Logger
    ROOT.get component
  end

  def self.root_filter
    ROOT.filter
  end

  def self.root_filter=(value)
    ROOT.filter = value
  end

  def self.root_emitters
    ROOT.emitters
  end

  def self.root_emitters=(value)
    ROOT.emitters = value
  end

  {% for level in Severity.constants %}
    {{ level }} = Severity::{{ level }}
  {% end %}
end
