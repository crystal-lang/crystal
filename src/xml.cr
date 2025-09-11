require "./xml/libxml2"

# The XML module allows parsing and generating [XML](https://www.w3.org/XML/) documents.
#
# NOTE: To use `XML`, you must explicitly import it with `require "xml"`
#
# ### Parsing
#
# `XML#parse` will parse xml from `String` or `IO` and return xml document as an `XML::Node` which represents all kinds of xml nodes.
#
# Example:
#
# ```
# require "xml"
#
# xml = <<-XML
#  <person id="1">
#   <firstname>Jane</firstname>
#   <lastname>Doe</lastname>
#  </person>
# XML
#
# document = XML.parse(xml)             # : XML::Node
# person = document.first_element_child # : XML::Node?
# if person
#   puts person["id"] # "1" : String?
#
#   puts typeof(person.children)                       # XML::NodeSet
#   person.children.select(&.element?).each do |child| # Select only element children
#     puts typeof(child)                               # XML::Node
#     puts child.name                                  # firstname : String
#     puts child.content                               # Jane : String?
#   end
# end
# ```
#
# ## Generating
#
# Use `XML.build`, which uses an `XML::Builder`:
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
module XML
  # Parses an XML document from *string* with *options* into an `XML::Node`.
  #
  # See `ParserOptions.default` for default options.
  def self.parse(string : String, options : ParserOptions = ParserOptions.default) : Document
    raise XML::Error.new("Document is empty", 0) if string.empty?
    ctxt = LibXML.xmlNewParserCtxt
    from_ptr(ctxt) do
      LibXML.xmlCtxtReadMemory(ctxt, string, string.bytesize, nil, nil, options)
    end
  end

  # Parses an XML document from *io* with *options* into an `XML::Node`.
  #
  # See `ParserOptions.default` for default options.
  def self.parse(io : IO, options : ParserOptions = ParserOptions.default) : Document
    ctxt = LibXML.xmlNewParserCtxt
    from_ptr(ctxt) do
      LibXML.xmlCtxtReadIO(ctxt, ->read_callback, ->close_callback, Box(IO).box(io), nil, nil, options)
    end
  end

  # Parses an HTML document from *string* with *options* into an `XML::Node`.
  #
  # See `HTMLParserOptions.default` for default options.
  def self.parse_html(string : String, options : HTMLParserOptions = HTMLParserOptions.default) : Document
    raise XML::Error.new("Document is empty", 0) if string.empty?
    ctxt = LibXML.htmlNewParserCtxt
    from_ptr(ctxt) do
      LibXML.htmlCtxtReadMemory(ctxt, string, string.bytesize, nil, "utf-8", options)
    end
  end

  # Parses an HTML document from *io* with *options* into an `XML::Node`.
  #
  # See `HTMLParserOptions.default` for default options.
  def self.parse_html(io : IO, options : HTMLParserOptions = HTMLParserOptions.default) : Document
    ctxt = LibXML.htmlNewParserCtxt
    from_ptr(ctxt) do
      LibXML.htmlCtxtReadIO(ctxt, ->read_callback, ->close_callback, Box(IO).box(io), nil, "utf-8", options)
    end
  end

  protected def self.read_callback(data : Void*, buffer : UInt8*, len : LibC::Int) : LibC::Int
    io = Box(IO).unbox(data)
    buf = Slice.new(buffer, len)
    ret = {% if LibXML.has_method?(:xmlCtxtSetErrorHandler) %}
            io.read(buf)
          {% else %}
            XML::Error.default_handlers { io.read(buf) }
          {% end %}
    LibC::Int.new(ret)
  end

  protected def self.close_callback(data : Void*) : LibC::Int
    LibC::Int.new(0)
  end

  protected def self.from_ptr(ctxt, & : -> LibXML::Doc*)
    errors = [] of XML::Error
    doc =
      {% if LibXML.has_method?(:xmlCtxtSetErrorHandler) %}
        LibXML.xmlCtxtSetErrorHandler(ctxt, ->Error.structured_callback, Box.box(errors))
        yield
      {% else %}
        XML::Error.unsafe_collect(errors) { yield }
      {% end %}
    raise Error.new(LibXML.xmlGetLastError) unless doc

    Document.new(doc, errors)
  end

  {% unless LibXML.has_method?(:xmlSaveSetIndentString) %}
    # NOTE: These helpers are for internal compatibility with libxml < 2.14.

    protected def self.with_indent_tree_output(indent : Bool, &)
      save_indent_tree_output do
        LibXML.__xmlIndentTreeOutput.value = indent ? 1 : 0
        yield
      end
    end

    protected def self.save_indent_tree_output(&)
      value = LibXML.__xmlIndentTreeOutput.value
      begin
        yield
      ensure
        LibXML.__xmlIndentTreeOutput.value = value
      end
    end

    protected def self.with_tree_indent_string(string : String, &)
      value = LibXML.__xmlTreeIndentString.value
      LibXML.__xmlTreeIndentString.value = string.to_unsafe
      begin
        yield
      ensure
        LibXML.__xmlTreeIndentString.value = value
      end
    end
  {% end %}

  class_getter libxml2_version : String do
    version_string = String.new(LibXML.xmlParserVersion)

    # The version string can contain extra information after the version number,
    # so we ignore any trailing non-numbers with `strict: false`
    number = version_string.to_i(strict: false)

    # Construct a formatted version string
    "#{number // 10_000}.#{number % 10_000 // 100}.#{number % 100}"
  end
end

require "./xml/*"
