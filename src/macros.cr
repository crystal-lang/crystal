macro record(name, *fields)
  struct {{name.id}}
    getter {{*fields}}

    def initialize({{ *fields.map { |field| "@#{field.id}".id } }})
    end

    {{yield}}

    def clone
      {{name.id}}.new({{ *fields.map { |field| "@#{field.id}.clone".id } }})
    end
  end
end

macro pp(exp)
  ::puts "#{ {{exp.stringify}} } = #{ ({{exp}}).inspect }"
end

macro assert_responds_to(var, method)
  if {{var}}.responds_to?(:{{method}})
    {{var}}
  else
    raise "expected {{var}} to respond to :{{method}}, not #{ {{var}} }"
  end
end

macro auto(node)
  {% if node.is_a?(ClassDef) %}
    {{ puts "Processing #{node}...".id }}
    {{ run "auto/process", "class", node }}
  {% elsif node.is_a?(Def) %}
    {{ puts "Processing #{@type}##{node.name}...".id }}
    {{ run "auto/process", "method", @type, node.name, *node.args }}
  {% end %}
end
