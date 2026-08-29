# An XML builder generates valid XML.
#
# An `XML::Error` is raised if attempting to generate
# an invalid XML (for example, if invoking `end_element`
# without a matching `start_element`, or trying to use
# a non-string value as an object's field name)
class XML::Builder
  private CDATA_END    = "]]>"
  private CDATA_ESCAPE = "]]]]><![CDATA[>"

  @box : Void*

  # Creates a builder that writes to the given *io*.
  def initialize(@io : IO)
    @box = Box.box(io)
    buffer = LibXML.xmlOutputBufferCreateIO(
      ->(ctx, buffer, len) {
        Box(IO).unbox(ctx).write_string(Slice.new(buffer, len))
        len
      },
      ->(ctx) {
        Box(IO).unbox(ctx).flush
        0
      },
      @box,
      nil
    )
    @writer = LibXML.xmlNewTextWriter(buffer)
  end

  # :nodoc:
  def finalize
    LibXML.xmlFreeTextWriter(@writer)
  end

  # Emits the start of the document.
  def start_document(version = nil, encoding = nil) : Nil
    call StartDocument, string_to_unsafe(version), string_to_unsafe(encoding), nil
  end

  # Emits the end of a document.
  def end_document : Nil
    call EndDocument
  end

  # Emits the start of the document, invokes the block,
  # and then emits the end of the document.
  def document(version = nil, encoding = nil, &)
    start_document version, encoding
    yield.tap { end_document }
  end

  # Emits the start of an element.
  def start_element(name : String) : Nil
    unsafe_name = string_to_unsafe(name)
    check_valid_element_name name, unsafe_name, "element name"
    call StartElement, unsafe_name
  end

  # Emits the start of an element with namespace info.
  def start_element(prefix : String?, name : String, namespace_uri : String?) : Nil
    unsafe_name = string_to_unsafe(name)
    unsafe_prefix = string_to_unsafe(prefix)

    check_valid_element_name name, unsafe_name, "element name"
    check_valid_element_name prefix, unsafe_prefix, "prefix" if prefix

    call StartElementNS, unsafe_prefix, unsafe_name, string_to_unsafe(namespace_uri)
  end

  # Emits the end of an element.
  def end_element : Nil
    call EndElement
  end

  # Emits the start of an element with the given *attributes*,
  # invokes the block and then emits the end of the element.
  def element(__name__ : String, **attributes, &)
    element(__name__, attributes) do
      yield
    end
  end

  # :ditto:
  def element(__name__ : String, attributes : Hash | NamedTuple, &)
    start_element __name__
    attributes(attributes)
    yield.tap { end_element }
  end

  # Emits an element with the given *attributes*.
  def element(__name__ : String, **attributes)
    element(__name__, attributes)
  end

  # :ditto:
  def element(name : String, attributes : Hash | NamedTuple) : Nil
    element(name, attributes) { }
  end

  # Emits the start of an element with namespace info with the given *attributes*,
  # invokes the block and then emits the end of the element.
  def element(__prefix__ : String?, __name__ : String, __namespace_uri__ : String?, **attributes, &)
    element(__prefix__, __name__, __namespace_uri__, attributes) do
      yield
    end
  end

  # :ditto:
  def element(__prefix__ : String?, __name__ : String, __namespace_uri__ : String?, attributes : Hash | NamedTuple, &)
    start_element __prefix__, __name__, __namespace_uri__
    attributes(attributes)
    yield.tap { end_element }
  end

  # Emits an element with namespace info with the given *attributes*.
  def element(prefix : String?, name : String, namespace_uri : String?, **attributes) : Nil
    element(prefix, name, namespace_uri, attributes)
  end

  # :ditto:
  def element(prefix : String?, name : String, namespace_uri : String?, attributes : Hash | NamedTuple) : Nil
    start_element(prefix, name, namespace_uri)
    attributes(attributes)
    end_element
  end

  # Emits the start of an attribute.
  def start_attribute(name : String) : Nil
    call StartAttribute, string_to_unsafe(name)
  end

  # Emits the start of an attribute with namespace info.
  def start_attribute(prefix : String?, name : String, namespace_uri : String?)
    call StartAttributeNS, string_to_unsafe(prefix), string_to_unsafe(name), string_to_unsafe(namespace_uri)
  end

  # Emits the end of an attribute.
  def end_attribute : Nil
    call EndAttribute
  end

  # Emits the start of an attribute, invokes the block,
  # and then emits the end of the attribute.
  def attribute(*args, **nargs, &)
    start_attribute *args, **nargs
    yield.tap { end_attribute }
  end

  # Emits an attribute with a *value*.
  def attribute(name : String, value) : Nil
    call WriteAttribute, string_to_unsafe(name), string_to_unsafe(value.to_s)
  end

  # Emits an attribute with namespace info and a *value*.
  def attribute(prefix : String?, name : String, namespace_uri : String?, value) : Nil
    call WriteAttributeNS, string_to_unsafe(prefix), string_to_unsafe(name), string_to_unsafe(namespace_uri), string_to_unsafe(value.to_s)
  end

  # Emits the given *attributes* with their values.
  def attributes(**attributes)
    attributes(attributes)
  end

  # :ditto:
  def attributes(attributes : Hash | NamedTuple) : Nil
    attributes.each do |key, value|
      attribute key.to_s, value
    end
  end

  # Emits text content.
  #
  # Text content can happen inside of an `element`, `attribute` value, `cdata`, `dtd`, etc.
  def text(content : String) : Nil
    call WriteString, string_to_unsafe(content)
  end

  # Emits the start of a `CDATA` section.
  def start_cdata : Nil
    call StartCDATA
  end

  # Emits the end of a `CDATA` section.
  def end_cdata : Nil
    call EndCDATA
  end

  # Emits the start of a `CDATA` section, invokes the block
  # and then emits the end of the `CDATA` section.
  #
  # NOTE: `CDATA` end sequences written within the block
  # need to be escaped manually.
  def cdata(&)
    start_cdata
    yield.tap { end_cdata }
  end

  # Emits a `CDATA` section.  Escapes nested `CDATA` end sequences.
  def cdata(text : String) : Nil
    call WriteCDATA, string_to_unsafe(text.gsub(CDATA_END, CDATA_ESCAPE))
  end

  # Emits the start of a comment.
  def start_comment : Nil
    call StartComment
  end

  # Emits the end of a comment.
  def end_comment : Nil
    call EndComment
  end

  # Emits the start of a comment, invokes the block
  # and then emits the end of the comment.
  def comment(&)
    start_comment
    yield.tap { end_comment }
  end

  # Emits a comment.
  def comment(text : String) : Nil
    call WriteComment, string_to_unsafe(text)
  end

  # Emits the start of a `DTD`.
  def start_dtd(name : String, pubid : String, sysid : String) : Nil
    call StartDTD, string_to_unsafe(name), string_to_unsafe(pubid), string_to_unsafe(sysid)
  end

  # Emits the end of a `DTD`.
  def end_dtd : Nil
    call EndDTD
  end

  # Emits the start of a `DTD`, invokes the block
  # and then emits the end of the `DTD`.
  def dtd(name : String, pubid : String, sysid : String, &) : Nil
    start_dtd name, pubid, sysid
    yield.tap { end_dtd }
  end

  # Emits a `DTD`.
  def dtd(name : String, pubid : String, sysid : String, subset : String? = nil) : Nil
    call WriteDTD, string_to_unsafe(name), string_to_unsafe(pubid), string_to_unsafe(sysid), string_to_unsafe(subset)
  end

  # Emits a namespace.
  def namespace(prefix, uri) : Nil
    attribute "xmlns", prefix, nil, uri
  end

  # Forces content written to this writer to be flushed to
  # this writer's `IO`.
  def flush : Nil
    call Flush

    @io.flush
  end

  # Sets the indent string.
  def indent=(str : String)
    if str.empty?
      call SetIndent, 0
    else
      call SetIndent, 1
      call SetIndentString, string_to_unsafe(str)
    end
  end

  # Sets the indent *level* (number of spaces).
  def indent=(level : Int)
    if level <= 0
      call SetIndent, 0
    else
      call SetIndent, 1
      call SetIndentString, " " * level
    end
  end

  # Sets the quote char to use, either `'` or `"`.
  def quote_char=(char : Char)
    unless char.in?('\'', '"')
      raise ArgumentError.new("Quote char must be ' or \", not #{char}")
    end

    call SetQuoteChar, char.ord
  end

  private macro call(name, *args)
    ret = LibXML.xmlTextWriter{{ name }}(@writer, {{ args.splat }})
    check ret, {{ @def.name.stringify }}
  end

  private def check(ret, msg)
    raise XML::Error.new("Error in #{msg}", 0) if ret < 0
  end

  private def check_valid_element_name(name : String, unsafe_name : Pointer(UInt8), element_type : String) : Nil
    raise XML::Error.new("Invalid #{element_type}: '#{name}'", 0) if LibXML.xmlValidateNameValue(unsafe_name).zero?
  end

  private def string_to_unsafe(string : String)
    raise XML::Error.new("String cannot contain null character", 0) if string.includes? '\0'
    string.to_unsafe
  end

  private def string_to_unsafe(string : Nil)
    Pointer(UInt8).null
  end
end

module XML
  # Returns the resulting `String` of writing XML to the yielded `XML::Builder`.
  #
  # Builds an XML document (see `#document`) including XML declaration (`<?xml?>`).
  #
  # ```
  # require "xml"
  #
  # string = XML.build(indent: "  ") do |xml|
  #   xml.element("person", id: 1) do
  #     xml.element("firstname") { xml.text "Jane" }
  #     xml.element("lastname") { xml.text "Doe" }
  #   end
  # end
  #
  # string # => "<?xml version=\"1.0\"?>\n<person id=\"1\">\n  <firstname>Jane</firstname>\n  <lastname>Doe</lastname>\n</person>\n"
  # ```
  def self.build(version : String? = nil, encoding : String? = nil, indent = nil, quote_char = nil, &)
    String.build do |str|
      build(str, version, encoding, indent, quote_char) do |xml|
        yield xml
      end
    end
  end

  # Returns the resulting `String` of writing XML to the yielded `XML::Builder`.
  #
  # Builds an XML fragment without XML declaration (`<?xml?>`).
  #
  # ```
  # require "xml"
  #
  # string = XML.build_fragment(indent: "  ") do |xml|
  #   xml.element("person", id: 1) do
  #     xml.element("firstname") { xml.text "Jane" }
  #     xml.element("lastname") { xml.text "Doe" }
  #   end
  # end
  #
  # string # => "<person id=\"1\">\n  <firstname>Jane</firstname>\n  <lastname>Doe</lastname>\n</person>\n"
  # ```
  def self.build_fragment(*, indent = nil, quote_char = nil, &)
    String.build do |str|
      build_fragment(str, indent: indent, quote_char: quote_char) do |xml|
        yield xml
      end
    end
  end

  # Writes XML document into the given `IO`. An `XML::Builder` is yielded to the block.
  #
  # Builds an XML document (see `#document`) including XML declaration (`<?xml?>`).
  def self.build(io : IO, version : String? = nil, encoding : String? = nil, indent = nil, quote_char = nil, &) : Nil
    build_fragment(io, indent: indent, quote_char: quote_char) do |xml|
      xml.start_document version, encoding
      yield xml
      # omit end_document because it is called in build_fragment
    end
  end

  # Writes XML fragment into the given `IO`. An `XML::Builder` is yielded to the block.
  #
  # Builds an XML fragment without XML declaration (`<?xml?>`).
  def self.build_fragment(io : IO, *, indent = nil, quote_char = nil, &) : Nil
    xml = XML::Builder.new(io)
    xml.indent = indent if indent
    xml.quote_char = quote_char if quote_char
    v = yield xml

    # EndDocument is still necessary to ensure all elements are closed, even
    # when StartDocument is omitted.
    xml.end_document
    xml.flush
    v
  end
end
