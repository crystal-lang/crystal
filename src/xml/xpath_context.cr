class XML::XPathContext
  getter errors = [] of XML::Error

  def initialize(node : Node)
    @ctx = LibXML.xmlXPathNewContext(node.to_unsafe.value.doc)
    @ctx.value.node = node.to_unsafe
  end

  def evaluate(search_path : String)
    xpath = XML::Error.collect_generic(@errors) { LibXML.xmlXPathEvalExpression(search_path, self) }

    raise XML::Error.new("Error in '#{search_path}' expression", 0) unless xpath

    case xpath.value.type
    when LibXML::XPathObjectType::STRING
      String.new(xpath.value.stringval)
    when LibXML::XPathObjectType::NUMBER
      xpath.value.floatval
    when LibXML::XPathObjectType::BOOLEAN
      xpath.value.boolval != 0
    when LibXML::XPathObjectType::NODESET
      if xpath.value.nodesetval
        NodeSet.new(Node.new(@ctx.value.doc), xpath.value.nodesetval)
      else
        NodeSet.new(Node.new(@ctx.value.doc))
      end
    else
      NodeSet.new(Node.new(@ctx.value.doc))
    end
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
