struct XML::Node
  LOOKS_LIKE_XPATH = /^(\.\/|\/|\.\.|\.$)/

  # Creates a new node.
  def initialize(node : LibXML::Attr*)
    initialize(node.as(LibXML::Node*))
  end

  # ditto
  def initialize(node : LibXML::Doc*)
    initialize(node.as(LibXML::Node*))
  end

  # ditto
  def initialize(node : LibXML::Doc*)
    initialize(node.as(LibXML::Node*))
  end

  # ditto
  def initialize(@node : LibXML::Node*)
  end

  # Gets the attribute content for the *attribute* given by name.
  # Raises `KeyError` if attribute is not found.
  def [](attribute : String) : String
    attributes[attribute].content || raise(KeyError.new("Missing attribute: #{attribute}"))
  end

  # Gets the attribute content for the *attribute* given by name.
  # Returns `nil` if attribute is not found.
  def []?(attribute : String) : String?
    attributes[attribute]?.try &.content
  end

  # Sets *attribute* of this node to *value*.
  # Raises `XML::Error` if this node does not support attributes.
  def []=(name : String, value)
    raise XML::Error.new("Can't set attribute of #{type}", 0) unless element?
    attributes[name] = value
  end

  # Deletes attribute given by *name*.
  # Returns attributes value, or `nil` if attribute not found.
  def delete(name : String)
    attributes.delete(name)
  end

  # Compares with *other*.
  def ==(other : Node)
    @node == other.@node
  end

  # Returns attributes of this node as an `XML::Attributes`.
  def attributes
    Attributes.new(self)
  end

  # Returns `true` if this is an attribute node.
  def attribute?
    type == XML::Type::ATTRIBUTE_NODE
  end

  # Returns `true` if this is a `CDATA` section node.
  def cdata?
    type == XML::Type::CDATA_SECTION_NODE
  end

  # Gets the list of children for this node as a `XML::NodeSet`.
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

  # Returns `true` if this is a comment node.
  def comment?
    type == XML::Type::COMMENT_NODE
  end

  # Returns the content for this Node. An empty string is
  # returned if the node has no content.
  def content : String
    content = LibXML.xmlNodeGetContent(self)
    content ? String.new(content) : ""
  end

  # Sets the Node's content to a Text node containing string.
  # The string gets XML escaped, not interpreted as markup.
  def content=(content)
    LibXML.xmlNodeSetContent(self, content.to_s)
  end

  # Gets the document for this Node as a `XML::Node`.
  def document
    Node.new @node.value.doc
  end

  # Returns `true` if this is a Document or HTML Document node.
  def document?
    case type
    when XML::Type::DOCUMENT_NODE,
         XML::Type::HTML_DOCUMENT_NODE
      true
    else
      false
    end
  end

  # Returns the encoding of this node's document.
  def encoding
    if document?
      encoding = @node.as(LibXML::Doc*).value.encoding
      encoding ? String.new(encoding) : nil
    else
      document.encoding
    end
  end

  # Returns the version of this node's document.
  def version
    if document?
      version = @node.as(LibXML::Doc*).value.version
      version ? String.new(version) : nil
    else
      document.version
    end
  end

  # Returns `true` if this is an Element node.
  def element?
    type == XML::Type::ELEMENT_NODE
  end

  # Returns the first child node of this node that is an element.
  # Returns `nil` if not found.
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

  # Returns `true` if this is a DocumentFragment.
  def fragment?
    type == XML::Type::DOCUMENT_FRAG_NODE
  end

  # See `Object#hash(hasher)`
  def_hash object_id

  # Returns the content for this Node.
  def inner_text
    content
  end

  # Returns detailed information for this node including node type, name, attributes and children.
  def inspect(io)
    io << "#<XML::"
    case type
    when XML::Type::ELEMENT_NODE       then io << "Element"
    when XML::Type::ATTRIBUTE_NODE     then io << "Attribute"
    when XML::Type::TEXT_NODE          then io << "Text"
    when XML::Type::CDATA_SECTION_NODE then io << "CData"
    when XML::Type::ENTITY_REF_NODE    then io << "EntityRef"
    when XML::Type::ENTITY_NODE        then io << "Entity"
    when XML::Type::PI_NODE            then io << "ProcessingInstruction"
    when XML::Type::COMMENT_NODE       then io << "Comment"
    when XML::Type::DOCUMENT_NODE      then io << "Document"
    when XML::Type::DOCUMENT_TYPE_NODE then io << "DocumentType"
    when XML::Type::DOCUMENT_FRAG_NODE then io << "DocumentFragment"
    when XML::Type::NOTATION_NODE      then io << "Notation"
    when XML::Type::HTML_DOCUMENT_NODE then io << "HTMLDocument"
    when XML::Type::DTD_NODE           then io << "DTD"
    when XML::Type::ELEMENT_DECL       then io << "Element"
    when XML::Type::ATTRIBUTE_DECL     then io << "AttributeDecl"
    when XML::Type::ENTITY_DECL        then io << "EntityDecl"
    when XML::Type::NAMESPACE_DECL     then io << "NamespaceDecl"
    when XML::Type::XINCLUDE_START     then io << "XIncludeStart"
    when XML::Type::XINCLUDE_END       then io << "XIncludeEnd"
    when XML::Type::DOCB_DOCUMENT_NODE then io << "DOCBDocument"
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

  # Returns the next sibling node or `nil` if not found.
  def next
    next_node = @node.value.next
    next_node ? Node.new(next_node) : nil
  end

  # ditto
  def next_sibling
    self.next
  end

  # Returns the next element node sibling or `nil` if not found.
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

  # Returns the name for this Node.
  def name
    if document?
      "document"
    elsif text?
      "text"
    elsif cdata?
      "#cdata-section"
    elsif fragment?
      "#document-fragment"
    elsif @node.value && @node.value.name
      String.new(@node.value.name)
    else
      ""
    end
  end

  # Sets the name for this Node.
  def name=(name)
    if document? || text? || cdata? || fragment?
      raise XML::Error.new("Can't set name of XML #{type}", 0)
    end
    LibXML.xmlNodeSetName(self, name.to_s)
  end

  # Returns the namespace for this node or `nil` if not found.
  def namespace
    case type
    when Type::DOCUMENT_NODE, Type::ATTRIBUTE_DECL, Type::DTD_NODE, Type::ELEMENT_DECL
      return nil
    end

    ns = @node.value.ns
    ns ? Namespace.new(document, ns) : nil
  end

  # Returns namespaces in scope for self – those defined on self element
  # directly or any ancestor node – as an `Array` of `XML::Namespace` objects.
  #
  # Default namespaces (`"xmlns="` style) for self are included in this array;
  # Default namespaces for ancestors, however, are not.
  #
  # See also `#namespaces`
  def namespace_scopes
    scopes = [] of Namespace

    ns_list = LibXML.xmlGetNsList(@node.value.doc, @node)

    if ns_list
      while ns_list.value
        scopes << Namespace.new(document, ns_list.value)
        ns_list += 1
      end
    end

    scopes
  end

  # Returns a `Hash(String, String?) of prefix => href` for all namespaces
  # on this node and its ancestors.
  #
  # This method returns the same namespaces as `#namespace_scopes`.
  #
  # Returns namespaces in scope for self – those defined on self element
  # directly or any ancestor node – as a `Hash` of attribute-name/value pairs.
  #
  # NOTE: Note that the keys in this hash XML attributes that would be used to
  # define this namespace, such as `"xmlns:prefix"`, not just the prefix.
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

  # Returns the address of underlying `LibXML::Node*` in memory.
  def object_id
    @node.address
  end

  # Returns the parent node or `nil` if not found.
  def parent
    parent = @node.value.parent
    parent ? Node.new(parent) : nil
  end

  # Returns the previous sibling node or `nil` if not found.
  def previous
    prev_node = @node.value.prev
    prev_node ? Node.new(prev_node) : nil
  end

  # Returns the previous sibling node that is an element or `nil` if not found.
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

  # Returns the previous sibling node or `nil` if not found.
  # Same with `#previous`.
  def previous_sibling
    previous
  end

  # Returns `true` if this is a Processing Instruction node.
  def processing_instruction?
    type == XML::Type::PI_NODE
  end

  # Returns the root node for this document or `nil`.
  def root
    root = LibXML.xmlDocGetRootElement(@node.value.doc)
    root ? Node.new(root) : nil
  end

  # Same as `#content`.
  def text
    content
  end

  # Same as `#content=`.
  def text=(text)
    self.content = text
  end

  # Returns `true` if this is a Text node.
  def text?
    type == XML::Type::TEXT_NODE
  end

  # Serialize this Node as XML to *io* using default options.
  #
  # See `#to_xml`.
  def to_s(io : IO)
    to_xml io
  end

  # Serialize this Node as XML and return a `String` using default options.
  #
  # See `XML::SaveOptions.xml_default` for default options.
  def to_xml(indent : Int = 2, indent_text = " ", options : SaveOptions = SaveOptions.xml_default)
    String.build do |str|
      to_xml str, indent, indent_text, options
    end
  end

  # :nodoc:
  SAVE_MUTEX = Thread::Mutex.new

  # Serialize this Node as XML to *io* using default options.
  #
  # See `XML::SaveOptions.xml_default` for default options.
  def to_xml(io : IO, indent = 2, indent_text = " ", options : SaveOptions = SaveOptions.xml_default)
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
        @node.value.doc.value.encoding,
        options)
      LibXML.xmlSaveTree(save_ctx, self)
      LibXML.xmlSaveClose(save_ctx)

      LibXML.xmlIndentTreeOutput = oldXmlIndentTreeOutput
      LibXML.xmlTreeIndentString = oldXmlTreeIndentString
    end

    io
  end

  # Returns underlying `LibXML::Node*` instance.
  def to_unsafe
    @node
  end

  # Returns the type for this Node as `XML::Type`.
  def type
    @node.value.type
  end

  # Removes the node from the XML document.
  def unlink
    LibXML.xmlUnlinkNode(self)
  end

  # Returns `true` if this is an xml Document node.
  def xml?
    type == XML::Type::DOCUMENT_NODE
  end

  # Searches this node for XPath *path*. Returns result with appropriate type
  # (`Bool | Float64 | String | XML::NodeSet`).
  #
  # Raises `XML::Error` on evaluation error.
  def xpath(path, namespaces = nil, variables = nil)
    ctx = XPathContext.new(self)
    ctx.register_namespaces namespaces if namespaces
    ctx.register_variables variables if variables
    ctx.evaluate(path)
  end

  # Searches this node for XPath *path* and restricts the return type to `Bool`.
  #
  # ```
  # require "xml"
  # doc = XML.parse("<person></person>")
  #
  # doc.xpath_bool("count(//person) > 0") # => true
  # ```
  def xpath_bool(path, namespaces = nil, variables = nil)
    xpath(path, namespaces).as(Bool)
  end

  # Searches this node for XPath *path* and restricts the return type to `Float64`.
  #
  # ```
  # doc.xpath_float("count(//person)") # => 1.0
  # ```
  def xpath_float(path, namespaces = nil, variables = nil)
    xpath(path, namespaces).as(Float64)
  end

  # Searches this node for XPath *path* and restricts the return type to `NodeSet`.
  #
  # ```
  # nodes = doc.xpath_nodes("//person")
  # nodes.class       # => XML::NodeSet
  # nodes.map(&.name) # => ["person"]
  # ```
  def xpath_nodes(path, namespaces = nil, variables = nil)
    xpath(path, namespaces).as(NodeSet)
  end

  # Searches this node for XPath *path* for nodes and returns the first one.
  # or `nil` if not found
  #
  # ```
  # doc.xpath_node("//person")  # => #<XML::Node:0x2013e80 name="person">
  # doc.xpath_node("//invalid") # => nil
  # ```
  def xpath_node(path, namespaces = nil, variables = nil)
    xpath_nodes(path, namespaces).first?
  end

  # Searches this node for XPath *path* and restricts the return type to `String`.
  #
  # ```
  # doc.xpath_string("string(/persons/person[1])")
  # ```
  def xpath_string(path, namespaces = nil, variables = nil)
    xpath(path, namespaces).as(String)
  end

  # :nodoc:
  def errors=(errors)
    @node.value._private = errors.as(Void*)
  end

  # Returns the list of `XML::Error` found when parsing this document.
  # Returns `nil` if no errors were found.
  def errors
    ptr = @node.value._private
    ptr ? (ptr.as(Array(XML::Error))) : nil
  end
end
