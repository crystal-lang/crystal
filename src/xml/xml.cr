module XML
  def self.parse(string : String, options : ParserOptions = ParserOptions.default) : Node
    from_ptr LibXML.xmlReadMemory(string, string.bytesize, nil, nil, options)
  end

  def self.parse(io : IO, options : ParserOptions = ParserOptions.default) : Node
    from_ptr LibXML.xmlReadIO(
      ->(ctx, buffer, len) {
        LibC::Int.new(Box(IO).unbox(ctx).read Slice.new(buffer, len))
      },
      ->(ctx) { 0 },
      Box(IO).box(io),
      nil,
      nil,
      options,
    )
  end

  def self.parse_html(string : String, options : HTMLParserOptions = HTMLParserOptions.default) : Node
    from_ptr LibXML.htmlReadMemory(string, string.bytesize, nil, nil, options)
  end

  def self.parse_html(io : IO, options : HTMLParserOptions = HTMLParserOptions.default) : Node
    from_ptr LibXML.htmlReadIO(
      ->(ctx, buffer, len) {
        LibC::Int.new(Box(IO).unbox(ctx).read Slice.new(buffer, len))
      },
      ->(ctx) { 0 },
      Box(IO).box(io),
      nil,
      nil,
      options,
    )
  end

  protected def self.from_ptr(doc : LibXML::Doc*)
    raise Error.new(LibXML.xmlGetLastError) unless doc

    node = Node.new(doc)
    XML::Error.set_errors(node)
    node
  end
end

require "./*"
