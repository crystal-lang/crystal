require "logger/*"

struct Logger
  getter component : String
  getter dispatcher : Dispatcher

  {% for level in Severity.constants %}
    {% unless level == "SILENT" %}
      def {{ level.downcase.id }}(message, *, time = Time.now, line_number = __LINE__, filename = __FILE__)
        dispatcher.call Entry.new(message, Severity::{{ level }}, component, time, line_number, filename)
      end
    {% end %}
  {% end %}

  def initialize(@component, @dispatcher)
  end

  class_getter default_dispatcher = Dispatcher.new(nil, IOEmitter.new)

  def self.get(component) : Logger
    default_dispatcher.get component
  end

  {% for level in Severity.constants %}
    {{ level }} = Severity::{{ level }}
  {% end %}
end
