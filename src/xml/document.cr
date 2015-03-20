require "./node"

module XML
  class Document < Node
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

    def self.from_ptr(doc : LibXML::DocPtr)
      if doc
        new doc
      else
        error = LibXML.xmlGetLastError
        raise Error.new(String.new(error.value.message).chomp, error.value.line)
      end
    end

    def initialize(doc : LibXML::DocPtr)
      node_common = doc as LibXML::NodeCommon*
      node_common.value._private = self as Void*
      super(node_common)
    end

    def document
      self
    end

    def name
      "document"
    end

    def root
      Node.from_ptr LibXML.xmlDocGetRootElement(to_doc)
    end

    def to_doc
      @node as LibXML::DocPtr
    end
  end
end
