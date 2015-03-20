require "./node"

module XML
  class Document < Node
    def self.parse(string : String, options = ParserOptions.default : ParserOptions)
      doc = LibXML.xmlReadMemory(string, string.bytesize, nil, nil, options)
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
