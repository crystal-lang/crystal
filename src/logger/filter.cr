require "./entry"

class Logger
  module Filter
    abstract def call(entry : Entry) : Bool
  end

  class HierarchyFilter
    include Filter

    property levels : Hash(String, Severity)

    def initialize(@levels = {} of String => Severity)
    end

    def call(entry : Entry)
      component = entry.component
      while true
        if level = @levels[component]?
          return entry.severity >= level
        end
        break if component.empty?
        component = component[0...(component.rindex("::") || 0)]
      end

      return true
    end

    forward_missing_to @levels
  end
end
