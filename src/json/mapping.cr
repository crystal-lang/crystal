class Object
  macro json_mapping(properties, strict = false)
    {% for key, value in properties %}
      {% properties[key] = {type: value} unless value.is_a?(HashLiteral) %}
    {% end %}

    {% for key, value in properties %}
      property {{key.id}} :: {{value[:type]}} {{ (value[:nilable] ? "?" : "").id }}
    {% end %}

    def initialize(_pull : Json::PullParser)
      {% for key, value in properties %}
        _{{key.id}} = nil
      {% end %}

      _pull.read_object do |_key|
        case _key
        {% for key, value in properties %}
          when {{value[:key] || key.id.stringify}}
            _{{key.id}} =
            {% if value[:nilable] == true %} _pull.read_null_or { {% end %}

            {% if value[:converter] %}
              {{value[:converter]}}.from_json(_pull)
            {% else %}
              {{value[:type]}}.new(_pull)
            {% end %}

            {% if value[:nilable] == true %} } {% end %}
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
          if _{{key.id}}.is_a?(Nil)
            raise "missing json attribute: {{(value[:key] || key).id}}"
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
          {% unless value[:emit_null] %}
            unless @{{key.id}}.nil?
          {% end %}

            json.field({{value[:key] || key.id.stringify}}) do
              {% if value[:converter] %}
                {{ value[:converter] }}.to_json(@{{key.id}}, io)
              {% else %}
                @{{key.id}}.to_json(io)
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
