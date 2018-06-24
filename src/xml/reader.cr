require "./libxml2"

struct XML::Reader
  def initialize(str : String)
    input = LibXML.xmlParserInputBufferCreateStatic(str, str.bytesize, 1)
    @reader = LibXML.xmlNewTextReader(input, "")
    LibXML.xmlTextReaderSetErrorHandler @reader, ->(arg, msg, severity, locator) do
      msg_str = String.new(msg).chomp
      line_number = LibXML.xmlTextReaderLocatorLineNumber(locator)
      raise Error.new(msg_str, line_number)
    end
  end

  def initialize(io : IO)
    input = LibXML.xmlParserInputBufferCreateIO(
      ->(context, buffer, length) { Box(IO).unbox(context).read(Slice.new(buffer, length)).to_i },
      ->(context) { Box(IO).unbox(context).close; 0 },
      Box(IO).box(io),
      1
    )
    @reader = LibXML.xmlNewTextReader(input, "")
  end

  def read
    LibXML.xmlTextReaderRead(@reader) == 1
  end

  def next
    LibXML.xmlTextReaderNext(@reader) == 1
  end

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

  def node_type
    LibXML.xmlTextReaderNodeType(@reader)
  end

  def name
    value = LibXML.xmlTextReaderConstName(@reader)
    String.new(value) if value
  end

  def empty_element?
    LibXML.xmlTextReaderIsEmptyElement(@reader) == 1
  end

  def has_attributes?
    LibXML.xmlTextReaderHasAttributes(@reader) == 1
  end

  def attributes_count
    LibXML.xmlTextReaderAttributeCount(@reader)
  end

  def move_to_first_attribute
    LibXML.xmlTextReaderMoveToFirstAttribute(@reader) == 1
  end

  def move_to_next_attribute
    LibXML.xmlTextReaderMoveToNextAttribute(@reader) == 1
  end

  def move_to_attribute(name)
    LibXML.xmlTextReaderMoveToAttribute(@reader, name.to_s) == 1
  end

  def attribute(name)
    value = LibXML.xmlTextReaderGetAttribute(@reader, name.to_s)
    String.new(value) if value
  end

  def move_to_element
    LibXML.xmlTextReaderMoveToElement(@reader) == 1
  end

  def depth
    LibXML.xmlTextReaderDepth(@reader)
  end

  def read_inner_xml
    xml = LibXML.xmlTextReaderReadInnerXml(@reader)
    String.new(xml) if xml
  end

  def read_outer_xml
    xml = LibXML.xmlTextReaderReadOuterXml(@reader)
    String.new(xml) if xml
  end

  def expand
    xml = LibXML.xmlTextReaderExpand(@reader)
    XML::Node.new(xml) if xml
  end

  def value
    value = LibXML.xmlTextReaderConstValue(@reader)
    String.new(value) if value
  end

  def to_unsafe
    @reader
  end
end
