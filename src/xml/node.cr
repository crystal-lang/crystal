require "weak_ref"

class XML::Node
  LOOKS_LIKE_XPATH = /^(\.\/|\/|\.\.|\.$)/

  # Every Node must keep a reference to its document Node. To keep things
  # simple, a document Node merely references itself. An unlinked node must
  # still reference its original document Node until adopted into another
  # document's tree (the libxml nodes keep a pointer to their libxml doc).
  @document : Node

  # :nodoc:
  #
  # The constructors allocate a XML::Node for a libxml node once, so we don't
  # finalize a document twice for example.
  #
  # We store the reference into the libxml struct (_private) for documents
  # because a document's XML::Node lives as long as its libxml doc.
  #
  # However we can lose references to subtree XML::Node, so using _private would
  # leave dangling pointers. We thus keep a cache of weak references to all
  # nodes in the document, so we can still collect lost references, and at worst
  # reinstantiate a XML::Node if needed.
  protected getter! cache : Hash(LibXML::Node*, WeakRef(Node))?

  # :nodoc:
  #
  # Unlinked Nodes, and all their descendant nodes, don't appear in the
  # document's tree anymore, and must be manually freed, yet we can't merely
  # free the libxml node in a finalizer, because it would free the whole
  # subtree, while we may still have live XML::Node instances.
  #
  # We keep an explicit list of unlinked libxml nodes. We can't rely on the
  # cache because it uses weak references and the Node could be collected,
  # leaking the libxml node and its subtree.
  #
  # WARNING: the libxml node, along with any descendant shall be removed from
  # the list when relinked into a tree, be it the same document or another.
  protected getter! unlinked_nodes : Set(LibXML::Node*)?

  # :nodoc:
  def self.new(doc : LibXML::Doc*, errors : Array(Error)? = nil)
    if ptr = doc.value._private
      ptr.as(Node)
    else
      new(doc_: doc, errors_: errors)
    end
  end

  # :nodoc:
  def self.new(node : LibXML::Node*, document : self) : self
    if node == document.@node
      # should never happen, but just in case
      return document
    end

    if obj = document.cached?(node)
      return obj
    end

    obj = new(node_: node, document_: document)
    document.cache[node] = WeakRef.new(obj)
    obj
  end

  # :nodoc:
  @[Deprecated]
  def self.new(node : LibXML::Node*) : self
    new(node, new(node.value.doc))
  end

  # :nodoc:
  @[Deprecated]
  def self.new(node : LibXML::Attr*) : self
    new(node.as(LibXML::Node*), new(node.value.doc))
  end

  # the initializers must never be called directly, use the constructors above

  private def initialize(*, doc_ : LibXML::Doc*, errors_ : Array(Error)?)
    @node = doc_.as(LibXML::Node*)
    @errors = errors_
    @cache = Hash(LibXML::Node*, WeakRef(Node)).new
    @unlinked_nodes = Set(LibXML::Node*).new
    @document = uninitialized Node
    @document = self
    doc_.value._private = self.as(Void*)
  end

  private def initialize(*, node_ : LibXML::Node*, document_ : self)
    @node = node_.as(LibXML::Node*)
    @document = document_
  end

  # :nodoc:
  def finalize
    return unless @document == self

    doc = @node.as(LibXML::Doc*)

    # free unlinked nodes and their subtrees
    unlinked_nodes.each do |node|
      if node.value.doc == doc
        LibXML.xmlFreeNode(node)
      else
        # the node has been adopted into another document, don't free!
      end
    end

    # free the doc and its subtree
    LibXML.xmlFreeDoc(@node.as(LibXML::Doc*))
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
    return NodeSet.new unless child

    size = 1
    while child = child.value.next
      size += 1
    end

    child = @node.value.children
    nodes = Slice(Node).new(size) do
      node = Node.new(child, @document)
      child = child.value.next
      node
    end

    NodeSet.new(nodes)
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

    if fragment? || element? || attribute?
      # libxml will immediately free all the children nodes, while we may have
      # live references to a child or a descendant; explicitly unlink all the
      # children before replacing the node's contents
      child = @node.value.children
      while child
        if node = document.cached?(child)
          node.unlink
        else
          document.unlinked_nodes << child
          LibXML.xmlUnlinkNode(child)
        end
        child = child.value.next
      end
    end

    LibXML.xmlNodeSetContent(self, content)
  end

  # Gets the document for this Node as a `XML::Node`.
  def document : XML::Node
    @document
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
    if encoding = @document.@node.as(LibXML::Doc*).value.encoding
      String.new(encoding)
    end
  end

  # Returns the version of this node's document.
  def version : String?
    if version = @document.@node.as(LibXML::Doc*).value.version
      String.new(version)
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
        return Node.new(child, @document)
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
    io << "#<XML::" << type_name << ":0x"
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

  def pretty_print(pp : PrettyPrint) : Nil
    pp.surround("#<XML::#{type_name}:0x#{object_id.to_s(16)}", ">", left_break: nil, right_break: nil) do
      if text?
        pp.breakable
        content.pretty_print(pp)
      else
        unless document?
          pp.breakable
          pp.group do
            pp.text "name="
            pp.nest do
              pp.breakable ""
              name.pretty_print(pp)
            end
          end
        end

        if attribute?
          pp.breakable
          pp.group do
            pp.text "content="
            pp.nest do
              pp.breakable ""
              content.pretty_print(pp)
            end
          end
        else
          attributes = self.attributes
          unless attributes.empty?
            pp.breakable
            pp.group do
              pp.text "attributes="
              pp.nest do
                pp.breakable ""
                attributes.pretty_print(pp)
              end
            end
          end

          children = self.children
          unless children.empty?
            pp.breakable
            pp.group do
              pp.text "children="
              pp.nest do
                pp.breakable ""
                children.pretty_print(pp)
              end
            end
          end
        end
      end
    end
  end

  private def type_name
    case type
    when XML::Node::Type::NONE               then "None"
    when XML::Node::Type::ELEMENT_NODE       then "Element"
    when XML::Node::Type::ATTRIBUTE_NODE     then "Attribute"
    when XML::Node::Type::TEXT_NODE          then "Text"
    when XML::Node::Type::CDATA_SECTION_NODE then "CData"
    when XML::Node::Type::ENTITY_REF_NODE    then "EntityRef"
    when XML::Node::Type::ENTITY_NODE        then "Entity"
    when XML::Node::Type::PI_NODE            then "ProcessingInstruction"
    when XML::Node::Type::COMMENT_NODE       then "Comment"
    when XML::Node::Type::DOCUMENT_NODE      then "Document"
    when XML::Node::Type::DOCUMENT_TYPE_NODE then "DocumentType"
    when XML::Node::Type::DOCUMENT_FRAG_NODE then "DocumentFragment"
    when XML::Node::Type::NOTATION_NODE      then "Notation"
    when XML::Node::Type::HTML_DOCUMENT_NODE then "HTMLDocument"
    when XML::Node::Type::DTD_NODE           then "DTD"
    when XML::Node::Type::ELEMENT_DECL       then "Element"
    when XML::Node::Type::ATTRIBUTE_DECL     then "AttributeDecl"
    when XML::Node::Type::ENTITY_DECL        then "EntityDecl"
    when XML::Node::Type::NAMESPACE_DECL     then "NamespaceDecl"
    when XML::Node::Type::XINCLUDE_START     then "XIncludeStart"
    when XML::Node::Type::XINCLUDE_END       then "XIncludeEnd"
    when XML::Node::Type::DOCB_DOCUMENT_NODE then "DOCBDocument"
    end
  end

  # Returns the next sibling node or `nil` if not found.
  def next : XML::Node?
    next_node = @node.value.next
    next_node ? Node.new(next_node, @document) : nil
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
        return Node.new(next_node, @document)
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
      ns ? Namespace.new(@document, ns) : nil
    end
  end

  # Returns namespaces defined on this node directly.
  def namespace_definitions : Array(Namespace)
    namespaces = [] of Namespace

    ns = @node.value.ns_def
    while ns
      namespaces << Namespace.new(@document, ns)
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
        yield Namespace.new(@document, ns_list.value)
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
    parent ? Node.new(parent, @document) : nil
  end

  # Returns the previous sibling node or `nil` if not found.
  def previous : XML::Node?
    prev_node = @node.value.prev
    prev_node ? Node.new(prev_node, @document) : nil
  end

  # Returns the previous sibling node that is an element or `nil` if not found.
  def previous_element : XML::Node?
    prev_node = @node.value.prev
    while prev_node
      if prev_node.value.type == XML::Node::Type::ELEMENT_NODE
        return Node.new(prev_node, @document)
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
    root ? Node.new(root, @document) : nil
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

  # Serialize this Node as XML to *io* using default options.
  #
  # See `XML::SaveOptions.xml_default` for default options.
  def to_xml(io : IO, indent = 2, indent_text = " ", options : SaveOptions = SaveOptions.xml_default)
    {% if LibXML.has_method?(:xmlSaveSetIndentString) %}
      # indentation is now always enabled by default (it can be disabled per
      # save context with the XML_SAVE_NO_INDENT option); the indent string is
      # explicitly set on the save context (no more global default)
      ctxt = LibXML.xmlSaveToIO(
        ->Node.write_callback,
        ->Node.close_callback,
        Box(IO).box(io),
        @node.value.doc.value.encoding,
        options)
      LibXML.xmlSaveSetIndentString(ctxt, indent_text * indent)
      LibXML.xmlSaveTree(ctxt, self)
      LibXML.xmlSaveClose(ctxt)
    {% else %}
      # indentation is disabled by default and it can only be enabled globally
      # for the current thread (no per context value)
      XML.with_indent_tree_output(true) do
        # the indent string will be copied to the save context... from the
        # default thread local value; at least we can reset the thread local
        # immediately after creating the save context
        ctxt = XML.with_tree_indent_string(indent_text * indent) do
          LibXML.xmlSaveToIO(
            ->Node.write_callback,
            ->Node.close_callback,
            Box(IO).box(io),
            @node.value.doc.value.encoding,
            options)
        end
        LibXML.xmlSaveTree(ctxt, self)
        LibXML.xmlSaveClose(ctxt)
      end
    {% end %}

    io
  end

  protected def self.write_callback(data : Void*, buffer : UInt8*, len : LibC::Int) : LibC::Int
    io = Box(IO).unbox(data)
    buf = Slice.new(buffer, len)

    {% if LibXML.has_method?(:xmlSaveSetIndentString) %}
      io.write_string(buf)
    {% else %}
      XML.save_indent_tree_output { io.write_string(buf) }
    {% end %}

    len
  end

  protected def self.close_callback(data : Void*) : LibC::Int
    # no need to save the indent tree output thread local, even though we flush
    # and the current fiber might swapcontext: libxml is closing the output and
    # won't write to the IO anymore
    Box(IO).unbox(data).flush
    LibC::Int.new(0)
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
    document.unlinked_nodes << @node
    LibXML.xmlUnlinkNode(@node)
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

  # these helpers must only be called on document nodes:

  protected def cached?(node : LibXML::Node*) : Node?
    cache[node]?.try(&.value)
  end

  protected def unlink_cached_children(node : LibXML::Node*) : Nil
    child = node.value.children
    while child
      if obj = cached?(node)
        obj.unlink
      else
        unlink_cached_children(child)
      end
      child = child.value.next
    end
  end
end
