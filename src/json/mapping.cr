class Object
  macro json_mapping(properties, strict = false)
    property {{*properties.keys}}

    def initialize(_pull : Json::PullParser)
      {% for key, value in properties %}
        _{{key.id}} = nil
      {% end %}

      _pull.read_object do |_key|
        case _key
        {% for key, value in properties %}
          when {{value[:key] || key.id.stringify}}
            {% if value[:nilable] == true %}
              _{{key.id}} = _pull.read_null_or { {{value[:type]}}.new(_pull) }
            {% else %}
              _{{key.id}} = {{value[:type]}}.new(_pull)
            {% end %}
        {% end %}
        else
          {% if strict %}
            raise "unknown json attribute: #{_key}"
          {% else %}
            _pull.skip
          {% end %}
        end
      end

      {% for key, value in properties %}
        {% unless value[:nilable] %}
          if _{{key.id}}.nil?
            raise "missing json attribute: {{(value[:key] || key).id}}"
          end
          _{{key.id}} = _{{key.id}}.not_nil!
        {% end %}
      {% end %}

      {% for key, value in properties %}
        @{{key.id}} = _{{key.id}}
      {% end %}
    end

    def to_json(io : IO)
      io.json_object do |json|
        {% for key, value in properties %}
          {% unless value[:emit_null] %}
            unless @{{key.id}}.nil?
          {% end %}

            json.field({{value[:key] || key.id.stringify}}) do
              @{{key.id}}.to_json(io)
            end

          {% unless value[:emit_null] %}
            end
          {% end %}
        {% end %}
      end
    end
  end
end
