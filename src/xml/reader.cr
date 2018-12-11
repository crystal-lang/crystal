require "./libxml2"
require "./parser_options"

struct XML::Reader
  # Creates a new reader from a string.
  #
  # See `XML::ParserOptions.default` for default options.
  def initialize(str : String, options : XML::ParserOptions = XML::ParserOptions.default)
    @reader = LibXML.xmlReaderForMemory(str, str.bytesize, nil, nil, options)
    LibXML.xmlTextReaderSetErrorHandler @reader, ->(arg, msg, severity, locator) do
      msg_str = String.new(msg).chomp
      line_number = LibXML.xmlTextReaderLocatorLineNumber(locator)
      raise Error.new(msg_str, line_number)
    end
  end

  # Creates a new reader from an IO.
  #
  # See `XML::ParserOptions.default` for default options.
  def initialize(io : IO, options : XML::ParserOptions = XML::ParserOptions.default)
    @reader = LibXML.xmlReaderForIO(
      ->(context, buffer, length) { Box(IO).unbox(context).read(Slice.new(buffer, length)).to_i },
      ->(context) { Box(IO).unbox(context).close; 0 },
      Box(IO).box(io),
      nil,
      nil,
      options
    )
  end

  # Moves the reader to the next node.
  def read
    LibXML.xmlTextReaderRead(@reader) == 1
  end

  # Moves the reader to the next node while skipping subtrees.
  def next
    LibXML.xmlTextReaderNext(@reader) == 1
  end

  # Moves the reader to the next sibling node while skipping subtrees.
  def next_sibling
    result = LibXML.xmlTextReaderNextSibling(@reader)
    # Work around libxml2 with incomplete xmlTextReaderNextSibling()
    # see: https://gitlab.gnome.org/GNOME/libxml2/issues/7
    if result == -1
      node = LibXML.xmlTextReaderCurrentNode(@reader)
      if node.null?
        LibXML.xmlTextReaderRead(@reader) == 1
      elsif !node.value.next.null?
        LibXML.xmlTextReaderNext(@reader) == 1
      else
        false
      end
    else
      result == 1
    end
  end

  # Returns the `XML::Type` of the node.
  def node_type
    LibXML.xmlTextReaderNodeType(@reader)
  end

  # Returns the name of the node.
  def name
    value = LibXML.xmlTextReaderConstName(@reader)
    value ? String.new(value) : ""
  end

  # Checks if the node is an empty element.
  def empty_element?
    LibXML.xmlTextReaderIsEmptyElement(@reader) == 1
  end

  # Checks if the node has any attributes.
  def has_attributes?
    LibXML.xmlTextReaderHasAttributes(@reader) == 1
  end

  # Returns attribute count of the node.
  def attributes_count
    LibXML.xmlTextReaderAttributeCount(@reader)
  end

  # Moves to the first `XML::Type::ATTRIBUTE_NODE` of the node.
  def move_to_first_attribute
    LibXML.xmlTextReaderMoveToFirstAttribute(@reader) == 1
  end

  # Moves to the next `XML::Type::ATTRIBUTE_NODE` of the node.
  def move_to_next_attribute
    LibXML.xmlTextReaderMoveToNextAttribute(@reader) == 1
  end

  # Moves to the `XML::Type::ATTRIBUTE_NODE` with the specified name.
  def move_to_attribute(name : String)
    LibXML.xmlTextReaderMoveToAttribute(@reader, name) == 1
  end

  # Gets the attribute content for the *attribute* given by name.
  # Raises `KeyError` if attribute is not found.
  def [](attribute : String) : String
    self[attribute]? || raise(KeyError.new("Missing attribute: #{attribute}"))
  end

  # Gets the attribute content for the *attribute* given by name.
  # Returns `nil` if attribute is not found.
  def []?(attribute : String) : String?
    value = LibXML.xmlTextReaderGetAttribute(@reader, attribute)
    String.new(value) if value
  end

  # Moves from the `XML::Type::ATTRIBUTE_NODE` to its containing `XML::Type::ELEMENT_NODE`.
  def move_to_element
    LibXML.xmlTextReaderMoveToElement(@reader) == 1
  end

  # Returns the current nesting depth of the reader.
  def depth
    LibXML.xmlTextReaderDepth(@reader)
  end

  # Returns the node's XML content including subtrees.
  def read_inner_xml
    xml = LibXML.xmlTextReaderReadInnerXml(@reader)
    xml ? String.new(xml) : ""
  end

  # Returns the XML for the node and its content including subtrees.
  def read_outer_xml
    xml = LibXML.xmlTextReaderReadOuterXml(@reader)
    xml ? String.new(xml) : ""
  end

  # Expands the node to a `XML::Node` that can be searched with XPath etc.
  # The returned `XML::Node` is only valid until the next call to `#read`.
  def expand
    xml = LibXML.xmlTextReaderExpand(@reader)
    XML::Node.new(xml) if xml
  end

  # Returns the text content of the node.
  def value
    value = LibXML.xmlTextReaderConstValue(@reader)
    value ? String.new(value) : ""
  end

  # Returns a reference to the underlying `LibXML::XMLTextReader`.
  def to_unsafe
    @reader
  end
end
