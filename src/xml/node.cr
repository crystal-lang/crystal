struct XML::Node
  LOOKS_LIKE_XPATH = /^(\.\/|\/|\.\.|\.$)/

  def initialize(node : LibXML::Attr*)
    initialize(node as LibXML::Node*)
  end

  def initialize(node : LibXML::DocPtr)
    initialize(node as LibXML::Node*)
  end

  def initialize(node : LibXML::DocPtr)
    initialize(node as LibXML::Node*)
  end

  def initialize(@node : LibXML::Node*)
  end

  def [](attribute : String)
    attributes[attribute].content
  end

  def []?(attribute : String)
    attributes[attribute]?.try &.content
  end

  def ==(other : Node)
    @node == other.@node
  end

  def attributes
    Attributes.new(self)
  end

  def attribute?
    type == XML::Type::ATTRIBUTE_NODE
  end

  def cdata?
    type == XML::Type::CDATA_SECTION_NODE
  end

  def children
    child = @node.value.children

    set = LibXML.xmlXPathNodeSetCreate(child)

    if child
      child = child.value.next
      while child
        LibXML.xmlXPathNodeSetAddUnique(set, child)
        child = child.value.next
      end
    end

    NodeSet.new(document, set)
  end

  def comment?
    type == XML::Type::COMMENT_NODE
  end

  def content
    content = LibXML.xmlNodeGetContent(self)
    if content
      String.new(content)
    else
      nil
    end
  end

  def document
    Node.new @node.value.doc
  end

  def document?
    type == XML::Type::DOCUMENT_NODE
  end

  def element?
    type == XML::Type::ELEMENT_NODE
  end

  def first_element_child
    child = @node.value.children
    while child
      if child.value.type == XML::Type::ELEMENT_NODE
        return Node.new(child)
      end
      child = child.value.next
    end
    nil
  end

  def fragment?
    type == XML::Type::DOCUMENT_FRAG_NODE
  end

  def hash
    object_id
  end

  def inner_text
    content
  end

  def inspect(io)
    io << "#<XML::"
    case type
    when XML::Type::ELEMENT_NODE        then io << "Element"
    when XML::Type::ATTRIBUTE_NODE      then io << "Attribute"
    when XML::Type::TEXT_NODE           then io << "Text"
    when XML::Type::CDATA_SECTION_NODE  then io << "CData"
    when XML::Type::ENTITY_REF_NODE     then io << "EntityRef"
    when XML::Type::ENTITY_NODE         then io << "Entity"
    when XML::Type::PI_NODE             then io << "ProcessingInstruction"
    when XML::Type::COMMENT_NODE        then io << "Comment"
    when XML::Type::DOCUMENT_NODE       then io << "Docuemnt"
    when XML::Type::DOCUMENT_TYPE_NODE  then io << "DocuemntType"
    when XML::Type::DOCUMENT_FRAG_NODE  then io << "DocuemntFragment"
    when XML::Type::NOTATION_NODE       then io << "Notation"
    when XML::Type::HTML_DOCUMENT_NODE  then io << "HTMLDocument"
    when XML::Type::DTD_NODE            then io << "DTD"
    when XML::Type::ELEMENT_DECL        then io << "Element"
    when XML::Type::ATTRIBUTE_DECL      then io << "AttributeDecl"
    when XML::Type::ENTITY_DECL         then io << "EntityDecl"
    when XML::Type::NAMESPACE_DECL      then io << "NamespaceDecl"
    when XML::Type::XINCLUDE_START      then io << "XIncludeStart"
    when XML::Type::XINCLUDE_END        then io << "XIncludeEnd"
    when XML::Type::DOCB_DOCUMENT_NODE  then io << "DOCBDocument"
    end

    io << ":0x"
    object_id.to_s(16, io)

    if text?
      io << " "
      content.inspect(io)
    else
      unless document?
        io << " name="
        name.inspect(io)
      end

      if attribute?
        io << " value="
        content.inspect(io)
      else
        attributes = self.attributes
        unless attributes.empty?
          io << " attributes="
          attributes.inspect(io)
        end

        children = self.children
        unless children.empty?
          io << " children="
          children.inspect(io)
        end
      end
    end

    io << ">"
    io
  end

  def next
    next_node = @node.value.next
    next_node ? Node.new(next_node) : nil
  end

  def next_sibling
    self.next
  end

  def next_element
    next_node = @node.value.next
    while next_node
      if next_node.value.type == XML::Type::ELEMENT_NODE
        return Node.new(next_node)
      end
      next_node = next_node.value.next
    end
    nil
  end

  def name
    if document?
      "document"
    elsif text?
      "text"
    elsif cdata?
      "#cdata-section"
    elsif fragment?
      "#document-fragment"
    else
      String.new(@node.value.name)
    end
  end

  def namespace
    case type
    when Type::DOCUMENT_NODE, Type::ATTRIBUTE_DECL, Type::DTD_NODE, Type::ELEMENT_DECL
      return nil
    end

    ns = @node.value.ns
    ns ? Namespace.new(document, ns) : nil
  end

  def namespace_scopes
    scopes = [] of Namespace

    ns_list = LibXML.xmlGetNsList(@node.value.doc, @node)
    while ns_list.value
      scopes << Namespace.new(document, ns_list.value)
      ns_list += 1
    end

    scopes
  end

  def namespaces
    namespaces = {} of String => String?

    ns_list = LibXML.xmlGetNsList(@node.value.doc, @node)

    if ns_list
      while ns_list.value
        namespace = Namespace.new(document, ns_list.value)
        prefix = namespace.prefix
        namespaces[prefix ? "xmlns:#{prefix}" : "xmlns"] = namespace.href
        ns_list += 1
      end
    end

    namespaces
  end

  def object_id
    @node.address
  end

  def parent
    parent = @node.value.parent
    parent ? Node.new(parent) : nil
  end

  def previous
    prev_node = @node.value.prev
    prev_node ? Node.new(prev_node) : nil
  end

  def previous_element
    prev_node = @node.value.prev
    while prev_node
      if prev_node.value.type == XML::Type::ELEMENT_NODE
        return Node.new(prev_node)
      end
      prev_node = prev_node.value.prev
    end
    nil
  end

  def previous_sibling
    previous
  end

  def processing_instruction?
    type == XML::Type::PI_NODE
  end

  def root
    root = LibXML.xmlDocGetRootElement(@node.value.doc)
    root ? Node.new(root) : nil
  end

  def text
    content
  end

  def text?
    type == XML::Type::TEXT_NODE
  end

  def to_s(io : IO)
    to_xml io
  end

  def to_xml(indent = 2 : Int, indent_text = " ", options = SaveOptions.xml_default : SaveOptions)
    String.build do |str|
      to_xml str, indent, indent_text, options
    end
  end

  # :nodoc:
  SAVE_MUTEX = Mutex.new

  def to_xml(io : IO, indent = 2, indent_text = " ", options = SaveOptions.xml_default : SaveOptions)
    # We need to use a mutex because we modify global libxml variables
    SAVE_MUTEX.synchronize do
      oldXmlIndentTreeOutput = LibXML.xmlIndentTreeOutput
      LibXML.xmlIndentTreeOutput = 1

      oldXmlTreeIndentString = LibXML.xmlTreeIndentString
      LibXML.xmlTreeIndentString = (indent_text * indent).to_unsafe

      save_ctx = LibXML.xmlSaveToIO(
        ->(ctx, buffer, len) {
          Box(IO).unbox(ctx).write Slice.new(buffer, len)
          len
        },
        ->(ctx) {
          Box(IO).unbox(ctx).flush
          0
        },
        Box(IO).box(io),
        nil,
        options)
      LibXML.xmlSaveTree(save_ctx, self)
      LibXML.xmlSaveClose(save_ctx)

      LibXML.xmlIndentTreeOutput = oldXmlIndentTreeOutput
      LibXML.xmlTreeIndentString = oldXmlTreeIndentString
    end

    io
  end

  def to_unsafe
    @node
  end

  def type
    @node.value.type
  end

  def xml?
    type == XML::Type::DOCUMENT_NODE
  end

  def xpath(path, namespaces = nil, variables = nil)
    ctx = XPathContext.new(self)
    ctx.register_namespaces namespaces if namespaces
    ctx.register_variables variables if variables
    ctx.evaluate(path)
  end

  def xpath_bool(path, namespaces = nil, variables = nil)
    xpath(path, namespaces) as Bool
  end

  def xpath_float(path, namespaces = nil, variables = nil)
    xpath(path, namespaces) as Float64
  end

  def xpath_nodes(path, namespaces = nil, variables = nil)
    xpath(path, namespaces) as NodeSet
  end

  def xpath_node(path, namespaces = nil, variables = nil)
    xpath_nodes(path, namespaces).first
  end

  def xpath_string(path, namespaces = nil, variables = nil)
    xpath(path, namespaces) as String
  end
end
