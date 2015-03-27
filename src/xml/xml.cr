module XML
  def self.parse(string : String, options = ParserOptions.default : ParserOptions)
    from_ptr LibXML.xmlReadMemory(string, string.bytesize, nil, nil, options)
  end

  def self.parse(io : IO, options = ParserOptions.default : ParserOptions)
    from_ptr LibXML.xmlReadIO(
      ->(ctx, buffer, len) {
        Box(IO).unbox(ctx).read Slice.new(buffer, len)
        len
      },
      ->(ctx) {
        0
      },
      Box(IO).box(io),
      nil,
      nil,
      options,
      )
  end

  protected def self.from_ptr(doc : LibXML::DocPtr)
    if doc
      Node.new doc
    else
      raise Error.new LibXML.xmlGetLastError
    end
  end
end

require "./*"

