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
  def self.parse(string : String, options : ParserOptions = ParserOptions.default) : Node
    raise XML::Error.new("Document is empty", 0) if string.empty?
    from_ptr { LibXML.xmlReadMemory(string, string.bytesize, nil, nil, options) }
  end

  # Parses an XML document from *io* with *options* into an `XML::Node`.
  #
  # See `ParserOptions.default` for default options.
  def self.parse(io : IO, options : ParserOptions = ParserOptions.default) : Node
    from_ptr { LibXML.xmlReadIO(
      ->(ctx, buffer, len) {
        LibC::Int.new(Box(IO).unbox(ctx).read Slice.new(buffer, len))
      },
      ->(ctx) { 0 },
      Box(IO).box(io),
      nil,
      nil,
      options,
    ) }
  end

  # Parses an HTML document from *string* with *options* into an `XML::Node`.
  #
  # See `HTMLParserOptions.default` for default options.
  def self.parse_html(string : String, options : HTMLParserOptions = HTMLParserOptions.default) : Node
    raise XML::Error.new("Document is empty", 0) if string.empty?
    from_ptr { LibXML.htmlReadMemory(string, string.bytesize, nil, "utf-8", options) }
  end

  # Parses an HTML document from *io* with *options* into an `XML::Node`.
  #
  # See `HTMLParserOptions.default` for default options.
  def self.parse_html(io : IO, options : HTMLParserOptions = HTMLParserOptions.default) : Node
    from_ptr { LibXML.htmlReadIO(
      ->(ctx, buffer, len) {
        LibC::Int.new(Box(IO).unbox(ctx).read Slice.new(buffer, len))
      },
      ->(ctx) { 0 },
      Box(IO).box(io),
      nil,
      "utf-8",
      options,
    ) }
  end

  protected def self.from_ptr(& : -> LibXML::Doc*)
    errors = [] of XML::Error
    doc = XML::Error.collect(errors) { yield }

    raise Error.new(LibXML.xmlGetLastError) unless doc

    Node.new(doc, errors)
  end

  protected def self.with_indent_tree_output(indent : Bool, &)
    ptr = LibXML.__xmlIndentTreeOutput
    old, ptr.value = ptr.value, indent ? 1 : 0
    begin
      yield
    ensure
      ptr.value = old
    end
  end

  protected def self.with_tree_indent_string(string : String, &)
    ptr = LibXML.__xmlTreeIndentString
    old, ptr.value = ptr.value, string.to_unsafe
    begin
      yield
    ensure
      ptr.value = old
    end
  end
end

require "./xml/*"
