# Macro helpers to implement the getter and property macros on `Object`.

module Crystal
  {% for prefixes in { {"", "", "@", "#"}, {"class_", "self.", "@@", "."} } %}
    {%
      macro_prefix = prefixes[0].id
      method_prefix = prefixes[1].id
      var_prefix = prefixes[2].id
      doc_prefix = prefixes[3]
    %}

    # :nodoc:
    macro def_{{macro_prefix}}var(name, nilable)
      \{% if name.is_a?(TypeDeclaration) %}
        \{% if nilable %}
          {{var_prefix}}\{{name.var.id}} : \{{name.type}}? \{% if name.value %} = \{{name.value}} \{% end %}
        \{% else %}
          {{var_prefix}}\{{name}}
        \{% end %}
      \{% elsif name.is_a?(Assign) %}
        {{var_prefix}}\{{name}}
      \{% end %}
    end

    {% for suffix in {"", "?"} %}
      # :nodoc:
      macro def_{{macro_prefix}}getter{{suffix.id}}(name, &block)
        \{% if name.is_a?(TypeDeclaration) %}
          \{% var_name = name.var.id %}
          \{% type = name.type %}
        \{% elsif name.is_a?(Assign) %}
          \{% var_name = name.target %}
          \{% type = nil %}
        \{% else %}
          \{% var_name = name.id %}
          \{% type = nil %}
        \{% end %}

        def {{method_prefix}}\{{var_name}}{{suffix.id}} \{% if type %} : \{{type}} \{% end %}
          \{% if block %}
            if (\%value = {{var_prefix}}\{{var_name}}).nil?
              {{var_prefix}}\{{var_name}} = \{{yield}}
            else
              \%value
            end
          \{% else %}
            {{var_prefix}}\{{var_name}}
          \{% end %}
        end
      end
    {% end %}

    # :nodoc:
    macro def_{{macro_prefix}}getter!(klass, name)
      \{% if name.is_a?(TypeDeclaration) %}
        \{% var_name = name.var.id %}
        \{% type = name.type %}
      \{% else %}
        \{% var_name = name.id %}
        \{% type = nil %}
      \{% end %}

      def {{method_prefix}}\{{var_name}}? \{% if type %} : \{{type}}? \{% end %}
        {{var_prefix}}\{{var_name}}
      end

      def {{method_prefix}}\{{var_name}} \{% if type %} : \{{type}} \{% end %}
        if (%value = {{var_prefix}}\{{var_name}}).nil?
          ::raise ::NilAssertionError.new(\{{"#{klass.id}#{{{doc_prefix}}.id}#{var_name} cannot be nil"}})
        else
          %value
        end
      end
    end

    # :nodoc:
    macro def_{{macro_prefix}}setter(name)
      \{% if name.is_a?(TypeDeclaration) %}
        def {{method_prefix}}\{{name.var.id}}=({{var_prefix}}\{{name.var.id}} : \{{name.type}})
        end
      \{% elsif name.is_a?(Assign) %}
        def {{method_prefix}}\{{name.target.id}}=({{var_prefix}}\{{name.target.id}})
        end
      \{% else %}
        def {{method_prefix}}\{{name.id}}=({{var_prefix}}\{{name.id}})
        end
      \{% end %}
    end
  {% end %}
end
