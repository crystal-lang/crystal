module YAML::Mapping
  macro yaml_mapping(properties, strict = false)
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

    def initialize(_pull : YAML::PullParser)
      {% for key, value in properties %}
        _{{key.id}} = nil
      {% end %}

      _pull.read_mapping_start
      while _pull.kind != YAML::EventKind::MAPPING_END
        _key = _pull.read_scalar.not_nil!
        case _key
        {% for key, value in properties %}
          when {{value[:key] || key.id.stringify}}
            _{{key.id}} =
            {% if value[:nilable] == true %} _pull.read_null_or { {% end %}

            {% if value[:converter] %}
              {{value[:converter]}}.from_yaml(_pull)
            {% else %}
              {{value[:type]}}.new(_pull)
            {% end %}

            {% if value[:nilable] == true %} } {% end %}
        {% end %}
        else
          {% if strict %}
            raise YAML::ParseException.new("unknown yaml attribute: #{_key}", 0, 0)
          {% else %}
            _pull.skip
          {% end %}
        end
      end
      _pull.read_next

      {% for key, value in properties %}
        {% unless value[:nilable] %}
          if _{{key.id}}.is_a?(Nil)
            raise YAML::ParseException.new("missing yaml attribute: {{(value[:key] || key).id}}", 0, 0)
          end
        {% end %}
      {% end %}

      {% for key, value in properties %}
        @{{key.id}} = _{{key.id}}
      {% end %}
    end
  end
end

class Object
  include YAML::Mapping
end
