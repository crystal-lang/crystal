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

  def node_type
    LibXML.xmlTextReaderNodeType(@reader)
  end

  def name
    String.new(LibXML.xmlTextReaderConstName(@reader))
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

  def value
    String.new(LibXML.xmlTextReaderConstValue(@reader))
  end

  def to_unsafe
    @reader
  end
end
