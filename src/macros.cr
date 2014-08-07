macro record(name, fields)
  struct {{name.id}}
    {% for field in fields %}
      getter :{{field.id}}
    {% end %}

    def initialize({{ (fields.map { |field| "@#{field.id}" }.join ", ").id }})
    end

    {{yield}}
  end
end

macro pp(exp)
  puts "{{exp}} = #{ {{exp}} }"
end

macro assert_responds_to(var, method)
  if {{var}}.responds_to?(:{{method}})
    {{var}}
  else
    raise "expected {{var}} to respond to :{{method}}, not #{ {{var}} }"
  end
end
