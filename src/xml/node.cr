class XML::Node
  LOOKS_LIKE_XPATH = /^(\.\/|\/|\.\.|\.$)/

  # Creates a new node.
  def initialize(node : LibXML::Attr*)
    initialize(node.as(LibXML::Node*))
  end

  # :ditto:
  def initialize(node : LibXML::Doc*, @errors : Array(XML::Error)? = nil)
    initialize(node.as(LibXML::Node*))
  end

  # :ditto:
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
  def delete(name : String) : String?
    attributes.delete(name)
  end

  # Compares with *other*.
  def ==(other : Node)
    @node == other.@node
  end

  # Returns attributes of this node as an `XML::Attributes`.
  def attributes : XML::Attributes
    Attributes.new(self)
  end

  # Returns `true` if this is an attribute node.
  def attribute? : Bool
    type == XML::Node::Type::ATTRIBUTE_NODE
  end

  # Returns `true` if this is a `CDATA` section node.
  def cdata? : Bool
    type == XML::Node::Type::CDATA_SECTION_NODE
  end

  # Gets the list of children for this node as a `XML::NodeSet`.
  def children : XML::NodeSet
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
    type == XML::Node::Type::COMMENT_NODE
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
    check_no_null_byte(content)
    LibXML.xmlNodeSetContent(self, content)
  end

  # Gets the document for this Node as a `XML::Node`.
  def document : XML::Node
    Node.new @node.value.doc
  end

  # Returns `true` if this is a Document or HTML Document node.
  def document? : Bool
    case type
    when XML::Node::Type::DOCUMENT_NODE,
         XML::Node::Type::HTML_DOCUMENT_NODE
      true
    else
      false
    end
  end

  # Returns the encoding of this node's document.
  def encoding : String?
    if document?
      encoding = @node.as(LibXML::Doc*).value.encoding
      encoding ? String.new(encoding) : nil
    else
      document.encoding
    end
  end

  # Returns the version of this node's document.
  def version : String?
    if document?
      version = @node.as(LibXML::Doc*).value.version
      version ? String.new(version) : nil
    else
      document.version
    end
  end

  # Returns `true` if this is an Element node.
  def element? : Bool
    type == XML::Node::Type::ELEMENT_NODE
  end

  # Returns the first child node of this node that is an element.
  # Returns `nil` if not found.
  def first_element_child : XML::Node?
    child = @node.value.children
    while child
      if child.value.type == XML::Node::Type::ELEMENT_NODE
        return Node.new(child)
      end
      child = child.value.next
    end
    nil
  end

  # Returns `true` if this is a DocumentFragment.
  def fragment? : Bool
    type == XML::Node::Type::DOCUMENT_FRAG_NODE
  end

  # See `Object#hash(hasher)`
  def_hash object_id

  # Returns the content for this Node.
  def inner_text : String
    content
  end

  # Returns detailed information for this node including node type, name, attributes and children.
  def inspect(io : IO) : Nil
    io << "#<XML::"
    case type
    when XML::Node::Type::NONE               then io << "None"
    when XML::Node::Type::ELEMENT_NODE       then io << "Element"
    when XML::Node::Type::ATTRIBUTE_NODE     then io << "Attribute"
    when XML::Node::Type::TEXT_NODE          then io << "Text"
    when XML::Node::Type::CDATA_SECTION_NODE then io << "CData"
    when XML::Node::Type::ENTITY_REF_NODE    then io << "EntityRef"
    when XML::Node::Type::ENTITY_NODE        then io << "Entity"
    when XML::Node::Type::PI_NODE            then io << "ProcessingInstruction"
    when XML::Node::Type::COMMENT_NODE       then io << "Comment"
    when XML::Node::Type::DOCUMENT_NODE      then io << "Document"
    when XML::Node::Type::DOCUMENT_TYPE_NODE then io << "DocumentType"
    when XML::Node::Type::DOCUMENT_FRAG_NODE then io << "DocumentFragment"
    when XML::Node::Type::NOTATION_NODE      then io << "Notation"
    when XML::Node::Type::HTML_DOCUMENT_NODE then io << "HTMLDocument"
    when XML::Node::Type::DTD_NODE           then io << "DTD"
    when XML::Node::Type::ELEMENT_DECL       then io << "Element"
    when XML::Node::Type::ATTRIBUTE_DECL     then io << "AttributeDecl"
    when XML::Node::Type::ENTITY_DECL        then io << "EntityDecl"
    when XML::Node::Type::NAMESPACE_DECL     then io << "NamespaceDecl"
    when XML::Node::Type::XINCLUDE_START     then io << "XIncludeStart"
    when XML::Node::Type::XINCLUDE_END       then io << "XIncludeEnd"
    when XML::Node::Type::DOCB_DOCUMENT_NODE then io << "DOCBDocument"
    end

    io << ":0x"
    object_id.to_s(io, 16)

    if text?
      io << ' '
      content.inspect(io)
    else
      unless document?
        io << " name="
        name.inspect(io)
      end

      if attribute?
        io << " content="
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

    io << '>'
  end

  # Returns the next sibling node or `nil` if not found.
  def next : XML::Node?
    next_node = @node.value.next
    next_node ? Node.new(next_node) : nil
  end

  # :ditto:
  def next_sibling : XML::Node?
    self.next
  end

  # Returns the next element node sibling or `nil` if not found.
  def next_element : XML::Node?
    next_node = @node.value.next
    while next_node
      if next_node.value.type == XML::Node::Type::ELEMENT_NODE
        return Node.new(next_node)
      end
      next_node = next_node.value.next
    end
    nil
  end

  # Returns the name for this Node.
  def name : String
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

    name = name.to_s

    if name.includes? '\0'
      raise XML::Error.new("Invalid node name: #{name.inspect} (contains null character)", 0)
    end

    if LibXML.xmlValidateNameValue(name) == 0
      raise XML::Error.new("Invalid node name: #{name.inspect}", 0)
    end

    LibXML.xmlNodeSetName(self, name)
  end

  # Returns the namespace for this node or `nil` if not found.
  def namespace : Namespace?
    case type
    when Type::DOCUMENT_NODE, Type::ATTRIBUTE_DECL, Type::DTD_NODE, Type::ELEMENT_DECL
      nil
    else
      ns = @node.value.ns
      ns ? Namespace.new(document, ns) : nil
    end
  end

  # Returns namespaces defined on this node directly.
  def namespace_definitions : Array(Namespace)
    namespaces = [] of Namespace

    ns = @node.value.ns_def
    while ns
      namespaces << Namespace.new(document, ns)
      ns = ns.value.next
    end

    namespaces
  end

  # Returns namespaces in scope for this node – those defined on this node
  # directly or any ancestor node – as an `Array` of `XML::Namespace` objects.
  #
  # Default namespaces (`"xmlns="` style) for this node are included in this
  # array; default namespaces for ancestors, however, are not.
  #
  # See also `#namespaces`
  def namespace_scopes : Array(Namespace)
    scopes = [] of Namespace

    each_namespace do |namespace|
      scopes << namespace
    end

    scopes
  end

  # Returns a `Hash(String, String?) of prefix => href` for all namespaces
  # on this node and its ancestors.
  #
  # This method returns the same namespaces as `#namespace_scopes`.
  #
  # Returns namespaces in scope for this node – those defined on this node
  # directly or any ancestor node – as a `Hash` of attribute-name/value pairs.
  #
  # NOTE: Note that the keys in this hash XML attributes that would be used to
  # define this namespace, such as `"xmlns:prefix"`, not just the prefix.
  def namespaces : Hash(String, String?)
    namespaces = {} of String => String?
    each_namespace do |namespace|
      prefix = namespace.prefix ? "xmlns:#{namespace.prefix}" : "xmlns"
      namespaces[prefix] = namespace.href
    end
    namespaces
  end

  protected def each_namespace(& : Namespace ->)
    ns_list = LibXML.xmlGetNsList(@node.value.doc, @node)

    if ns_list
      while ns_list.value
        yield Namespace.new(document, ns_list.value)
        ns_list += 1
      end
    end
  end

  # Returns the address of underlying `LibXML::Node*` in memory.
  def object_id : UInt64
    @node.address
  end

  # Returns the parent node or `nil` if not found.
  def parent : XML::Node?
    parent = @node.value.parent
    parent ? Node.new(parent) : nil
  end

  # Returns the previous sibling node or `nil` if not found.
  def previous : XML::Node?
    prev_node = @node.value.prev
    prev_node ? Node.new(prev_node) : nil
  end

  # Returns the previous sibling node that is an element or `nil` if not found.
  def previous_element : XML::Node?
    prev_node = @node.value.prev
    while prev_node
      if prev_node.value.type == XML::Node::Type::ELEMENT_NODE
        return Node.new(prev_node)
      end
      prev_node = prev_node.value.prev
    end
    nil
  end

  # Returns the previous sibling node or `nil` if not found.
  # Same with `#previous`.
  def previous_sibling : XML::Node?
    previous
  end

  # Returns `true` if this is a Processing Instruction node.
  def processing_instruction?
    type == XML::Node::Type::PI_NODE
  end

  # Returns the root node for this document or `nil`.
  def root : XML::Node?
    root = LibXML.xmlDocGetRootElement(@node.value.doc)
    root ? Node.new(root) : nil
  end

  # Same as `#content`.
  def text : String
    content
  end

  # Same as `#content=`.
  def text=(text)
    self.content = text
  end

  # Returns `true` if this is a Text node.
  def text? : Bool
    type == XML::Node::Type::TEXT_NODE
  end

  # Serialize this Node as XML to *io* using default options.
  #
  # See `#to_xml`.
  def to_s(io : IO) : Nil
    to_xml io
  end

  # Serialize this Node as XML and return a `String` using default options.
  #
  # See `XML::SaveOptions.xml_default` for default options.
  def to_xml(indent : Int = 2, indent_text = " ", options : SaveOptions = SaveOptions.xml_default) : String
    String.build do |str|
      to_xml str, indent, indent_text, options
    end
  end

  # :nodoc:
  SAVE_MUTEX = ::Mutex.new

  # Serialize this Node as XML to *io* using default options.
  #
  # See `XML::SaveOptions.xml_default` for default options.
  def to_xml(io : IO, indent = 2, indent_text = " ", options : SaveOptions = SaveOptions.xml_default)
    # We need to use a mutex because we modify global libxml variables
    SAVE_MUTEX.synchronize do
      XML.with_indent_tree_output(true) do
        XML.with_tree_indent_string(indent_text * indent) do
          save_ctx = LibXML.xmlSaveToIO(
            ->(ctx, buffer, len) {
              Box(IO).unbox(ctx).write_string Slice.new(buffer, len)
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
        end
      end
    end

    io
  end

  # Returns underlying `LibXML::Node*` instance.
  def to_unsafe
    @node
  end

  # Returns the type for this Node as `XML::Node::Type`.
  def type : XML::Node::Type
    @node.value.type
  end

  # Removes the node from the XML document.
  def unlink : Nil
    LibXML.xmlUnlinkNode(self)
  end

  # Returns `true` if this is an xml Document node.
  def xml?
    type == XML::Node::Type::DOCUMENT_NODE
  end

  # Searches this node for XPath *path*. Returns result with appropriate type
  # (`Bool | Float64 | String | XML::NodeSet`).
  #
  # Raises `XML::Error` on evaluation error.
  def xpath(path, namespaces = nil, variables = nil)
    ctx = XPathContext.new(self)

    if namespaces
      ctx.register_namespaces namespaces
    else
      root.try &.each_namespace do |namespace|
        ctx.register_namespace namespace.prefix || "xmlns", namespace.href
      end
    end

    ctx.register_variables variables if variables
    ctx.evaluate(path)
  end

  # Searches this node for XPath *path* and restricts the return type to `Bool`.
  #
  # ```
  # require "xml"
  #
  # doc = XML.parse("<person></person>")
  #
  # doc.xpath_bool("count(//person) > 0") # => true
  # ```
  def xpath_bool(path, namespaces = nil, variables = nil)
    xpath(path, namespaces, variables).as(Bool)
  end

  # Searches this node for XPath *path* and restricts the return type to `Float64`.
  #
  # ```
  # require "xml"
  #
  # doc = XML.parse("<person></person>")
  #
  # doc.xpath_float("count(//person)") # => 1.0
  # ```
  def xpath_float(path, namespaces = nil, variables = nil)
    xpath(path, namespaces, variables).as(Float64)
  end

  # Searches this node for XPath *path* and restricts the return type to `NodeSet`.
  #
  # ```
  # require "xml"
  #
  # doc = XML.parse("<person></person>")
  #
  # nodes = doc.xpath_nodes("//person")
  # nodes.class       # => XML::NodeSet
  # nodes.map(&.name) # => ["person"]
  # ```
  def xpath_nodes(path, namespaces = nil, variables = nil)
    xpath(path, namespaces, variables).as(NodeSet)
  end

  # Searches this node for XPath *path* for nodes and returns the first one.
  # or `nil` if not found
  #
  # ```
  # require "xml"
  #
  # doc = XML.parse("<person></person>")
  #
  # doc.xpath_node("//person")  # => #<XML::Node:0x2013e80 name="person">
  # doc.xpath_node("//invalid") # => nil
  # ```
  def xpath_node(path, namespaces = nil, variables = nil)
    xpath_nodes(path, namespaces, variables).first?
  end

  # Searches this node for XPath *path* and restricts the return type to `String`.
  #
  # ```
  # require "xml"
  #
  # doc = XML.parse("<person></person>")
  #
  # doc.xpath_string("string(/persons/person[1])")
  # ```
  def xpath_string(path, namespaces = nil, variables = nil)
    xpath(path, namespaces, variables).as(String)
  end

  # Returns the list of `XML::Error` found when parsing this document.
  # Returns `nil` if no errors were found.
  def errors : Array(XML::Error)?
    return @errors unless @errors.try &.empty?
  end

  private def check_no_null_byte(string)
    if string.includes? Char::ZERO
      raise XML::Error.new("Cannot escape string containing null character", 0)
    end
  end
end
