module XML
  struct Any
    alias Type = Nil | Bool | Int64 | Float64 | String | Array(Any) | Hash(String, Any)

    # Returns the raw underlying value.
    getter raw : Type

    def initialize(@raw : Type)
    end
  end

  annotation Element
  end

  module Serializable
    annotation Options
    end

    macro included
      def self.new(node : ::XML::Node)
        new_from_xml_node(node)
      end

      private def self.new_from_xml_node(node : ::XML::Node)
        instance = allocate
        instance.initialize(__for_xml_serializable: node)
        GC.add_finalizer(instance) if instance.responds_to?(:finalize)
        instance
      end

      macro inherited
        def self.new(node : ::XML::Node)
          new_from_xml_node(node)
        end
      end
    end

    def initialize(*, __for_xml_serializable node : ::XML::Node)
      {% begin %}
        {% properties = {} of Nil => Nil %}
        {% for ivar in @type.instance_vars %}
          {% ann = ivar.annotation(::XML::Element) %}
          {% unless ann && (ann[:ignore] || ann[:ignore_deserialize]) %}
            {%
              properties[ivar.id] = {
                type:        ivar.type,
                key:         ((ann && ann[:key]) || ivar).id.stringify,
                has_default: ivar.has_default_value?,
                default:     ivar.default_value,
                nilable:     ivar.type.nilable?,
                root:        ann && ann[:root],
                converter:   ann && ann[:converter],
                presence:    ann && ann[:presence],

              }
            %}
          {% end %}

          {% for name, value in properties %}
            %var{name} = nil
            %found{name} = false
          {% end %}

          begin
            if node.document?
              root = node.root
              if root.nil?
                raise ::XML::SerializableError.new("Missing XML root document", self.class.to_s, nil, 0)
              else
                children = root.children
              end
            else
              children = node.children
            end
          rescue exc : ::XML::Error
            raise ::XML::SerializableError.new(exc.message, self.class.to_s, nil, exc.line_number)
          end

          children.each do |child|
            next unless child.element?

            case child.name
            {% for name, value in properties %}
              when {{value[:key]}}
                %found{name} = true

                begin
                {% if value[:nilable] || value[:has_default] %}
                {% end %}

                {% if value[:converter] %}
                  %var{name} = {{value[:converter]}}.from_xml(child)
                {% else %}
                  %var{name} = ::Union({{value[:type]}}).new(child)
                {% end %}

                rescue exc : ::XML::Error
                  raise ::XML::SerializableError.new(exc.message, self.class.to_s, {{value[:key]}}, exc.line_number)
                end
            {% end %}
            else
              on_unknown_xml_attribute(child, child.name)
            end
          end

          {% for name, value in properties %}
            {% unless value[:nilable] || value[:has_default] %}
              if %var{name}.nil? && !%found{name} && !::Union({{value[:type]}}).nilable?
                raise ::XML::SerializableError.new("Missing XML node: {{value[:key].id}}", self.class.to_s, nil, 0)
              end
            {% end %}

            {% if value[:nilable] %}
              {% if value[:has_default].nil? %}
                @{{name}} = %var{name}
              {% else %}
                @{{name}} = %found{name} ? %var{name} : {{value[:default]}}
              {% end %}
            {% elsif value[:has_default] %}
              if %found{name} && !%var{name}.nil?
                @{{name}} = %var{name}
              end
            {% else %}
              @{{name}} = %var{name}.as({{value[:type]}})
            {% end %}

            {% if value[:presence] %}
              @{{name}}_present = %found{name}
            {% end %}
          {% end %}
        {% end %}
      {% end %}

      after_initialize
    end

    protected def after_initialize
    end

    protected def on_unknown_xml_attribute(node, key)
    end

    def to_xml
      XML.build(version: "1.0") do |xml|
        {% begin %}
          {% options = @type.annotation(::XML::Serializable::Options) %}
          {% emit_nulls = options && options[:emit_nulls] %}

          {% properties = {} of Nil => Nil %}
          {% for ivar in @type.instance_vars %}
            {% ann = ivar.annotation(::XML::Element) %}
            {% unless ann && (ann[:ignore] || ann[:ignore_serialize]) %}
              {%
                properties[ivar.id] = {
                  type:             ivar.type,
                  key:              ((ann && ann[:key]) || ivar).id.stringify,
                  root:             ann && ann[:root],
                  converter:        ann && ann[:converter],
                  emit_null:        (ann && (ann[:emit_null] != nil) ? ann[:emit_null] : emit_nulls),
                  ignore_serialize: ann && ann[:ignore_serialize],
                }
              %}
            {% end %}
          {% end %}

          xml.element({{@type.name.stringify}}) do
            {% for name, value in properties %}
              _{{name}} = @{{name}}

              {% if value[:ignore_serialize] %}
                unless {{ value[:ignore_serialize] }}
              {% end %}

              {% unless value[:emit_null] %}
                unless _{{name}}.nil?
              {% end %}

              xml.element({{value[:key]}}) do
                {% if value[:converter] %}
                  if _{{name}}
                    {{ value[:converter] }}.to_xml(_{{name}}, xml)
                  else
                    nil.to_xml(xml)
                  end
                {% else %}
                  _{{name}}.to_xml(xml)
                {% end %}

                if _{{name}}
                else
                end
              end

              {% unless value[:emit_null] %}
                end
              {% end %}

              {% if value[:ignore_serialize] %}
                end
              {% end %}
            {% end %}
          end
        {% end %}
      end
    end

    module Strict
      protected def on_unknown_xml_attribute(node, key)
        raise ::XML::SerializableError.new("Unknown XML attribute: #{key}", self.class.to_s, nil, 0)
      end
    end

    module Unmapped
      @[XML::Element(ignore: true)]
      property xml_unmapped = Hash(String, XML::Any).new

      protected def on_unknown_xml_attribute(node, name)
        xml_unmapped[name] = begin
          XML::Any.new(node.content)
        end
      end
    end
  end

  class SerializableError < XML::Error
    getter klass : String
    getter attribute : String?

    def initialize(message : String?, @klass : String, @attribute : String?, line_number : Int32)
      message = String.build do |io|
        io << message
        io << "\n  parsing "
        io << klass
        if attribute = @attribute
          io << '#' << attribute
        end
      end
      super(message, line_number)
    end
  end
end
