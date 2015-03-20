require "./node"

module XML
  class Element < Node
    protected def to_ptr
      @node as LibXML::NodeCommon*
    end
  end
end
