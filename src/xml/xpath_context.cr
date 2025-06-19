class XML::XPathContext
  getter errors = [] of XML::Error

  def initialize(@node : Node)
    @ctx = LibXML.xmlXPathNewContext(@node.to_unsafe.value.doc)
    @ctx.value.node = @node.to_unsafe

    {% if LibXML.has_method?(:xmlXPathSetErrorHandler) %}
      LibXML.xmlXPathSetErrorHandler(@ctx, ->Error.structured_callback, Box.box(@errors))
    {% end %}
  end

  # :nodoc:
  def finalize
    LibXML.xmlXPathFreeContext(@ctx)
  end

  def evaluate(search_path : String)
    xpath_object =
      {% if LibXML.has_method?(:xmlXPathSetErrorHandler) %}
        LibXML.xmlXPathEvalExpression(search_path, self)
      {% else %}
        XML::Error.unsafe_collect(errors) do
          LibXML.xmlXPathEvalExpression(search_path, self)
        end
      {% end %}

    unless xpath_object
      if error = @errors.first?
        raise error
      else
        raise XML::Error.new("Error in '#{search_path}' expression", 0)
      end
    end

    retval =
      case xpath_object.value.type
      when LibXML::XPathObjectType::STRING
        String.new(xpath_object.value.stringval)
      when LibXML::XPathObjectType::NUMBER
        xpath_object.value.floatval
      when LibXML::XPathObjectType::BOOLEAN
        xpath_object.value.boolval != 0
      when LibXML::XPathObjectType::NODESET
        NodeSet.new(xpath_object.value.nodesetval, @node.document)
      else
        NodeSet.new
      end

    LibXML.xmlXPathFreeObject(xpath_object)
    retval
  end

  def register_namespaces(namespaces) : Nil
    namespaces.each do |prefix, uri|
      register_namespace prefix, uri
    end
  end

  def register_namespace(prefix : String, uri : String?)
    prefix = prefix.lchop("xmlns:")
    LibXML.xmlXPathRegisterNs(self, prefix, uri.to_s)
  end

  def register_variables(variables) : Nil
    variables.each do |name, value|
      register_variable name, value
    end
  end

  def register_variable(name, value)
    case value
    when Bool
      obj = LibXML.xmlXPathNewBoolean(value ? 1 : 0)
    when Number
      obj = LibXML.xmlXPathNewFloat(value.to_f64)
    else
      obj = LibXML.xmlXPathNewCString(value.to_s)
    end

    LibXML.xmlXPathRegisterVariable(self, name, obj)
  end

  def to_unsafe
    @ctx
  end
end

LibXML.xmlXPathInit
