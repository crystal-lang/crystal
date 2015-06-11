class Object
  macro json_mapping(properties, strict = false)
    {% for key, value in properties %}
      {% properties[key] = {type: value} unless value.is_a?(HashLiteral) %}
    {% end %}

    {% for key, value in properties %}
      def {{key.id}}=(_{{key.id}} : {{value[:type]}} {{ (value[:nilable] ? "?" : "").id }})
        @{{key.id}} = _{{key.id}}
      end

      def {{key.id}}
        @{{key.id}}
      end
    {% end %}

    def initialize(_pull : JSON::PullParser)
      {% for key, value in properties %}
        _{{key.id}} = nil
      {% end %}

      _pull.read_object do |_key|
        case _key
        {% for key, value in properties %}
          when {{value[:key] || key.id.stringify}}
            {% unless value[:root] %} _{{key.id}} = {% end %}
            {% if value[:nilable] == true %} _pull.read_null_or { {% end %}

            {% if value[:root] %}
              _pull.read_object do |_nested_key|
                case _nested_key
                when  {{value[:root]}}
                  _{{key.id}} =
            {% end %}

            {% if value[:converter] %}
              {{value[:converter]}}.from_json(_pull)
            {% else %}
              {{value[:type]}}.new(_pull)
            {% end %}

            {% if value[:root] %}
                else
                  {% if strict %}
                    raise JSON::ParseException.new("unknown json attribute: #{_nested_key}", 0, 0)
                  {% else %}
                    _pull.skip
                  {% end %}
                end
              end
            {% end %}

            {% if value[:nilable] == true %} } {% end %}
        {% end %}
        else
          {% if strict %}
            raise JSON::ParseException.new("unknown json attribute: #{_key}", 0, 0)
          {% else %}
            _pull.skip
          {% end %}
        end
      end

      {% for key, value in properties %}
        {% unless value[:nilable] %}
          if _{{key.id}}.is_a?(Nil)
            raise JSON::ParseException.new("missing json attribute: {{(value[:key] || key).id}}", 0, 0)
          end
        {% end %}
      {% end %}

      {% for key, value in properties %}
        @{{key.id}} = _{{key.id}}
      {% end %}
    end

    def to_json(io : IO)
      io.json_object do |json|
        {% for key, value in properties %}
          _{{key.id}} = @{{key.id}}

          {% unless value[:emit_null] %}
            unless _{{key.id}}.is_a?(Nil)
          {% end %}

            json.field({{value[:key] || key.id.stringify}}) do
              {% if value[:root] %}
                io.json_object do |json|
                  json.field({{value[:root]}}) do
              {% end %}
              {% if value[:converter] %}
                if _{{key.id}}
                  {{ value[:converter] }}.to_json(_{{key.id}}, io)
                else
                  nil.to_json(io)
                end
              {% else %}
                _{{key.id}}.to_json(io)
              {% end %}
              {% if value[:root] %}
                  end
                end
              {% end %}
            end

          {% unless value[:emit_null] %}
            end
          {% end %}
        {% end %}
      end
    end
  end
end
