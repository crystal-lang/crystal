module XML
  abstract class Node
    def self.from_ptr(node : LibXML::Node*)
      return nil unless node

      case node.value.type
      when Type::Element
        Element.new(node)
      when Type::Text
        Text.new(node)
      else
        raise "Unknown node type: #{node.value.type}"
      end
    end

    def initialize(node : LibXML::Node*)
      @node = node as LibXML::NodeCommon*
    end

    def initialize(@node : LibXML::NodeCommon*)
    end

    def attributes
      Attributes.new(self)
    end

    def children
      child = @node.value.children

      set = LibXML.xmlXPathNodeSetCreate(child)

      if child
        child = child.value.next
        while child
          LibXML.xmlXPathNodeSetAddUnique(set, child)
          child = child.value.next
        end
      end

      NodeSet.new(document, set)
    end

    def content
      content = LibXML.xmlNodeGetContent(self)
      if content
        String.new(content)
      else
        nil
      end
    end

    def document
      (@node.value.doc as LibXML::NodeCommon*).value._private as Document
    end

    def name
      String.new(@node.value.name)
    end

    def parent
      parent = @node.value.parent
      parent ? Node.from_ptr(parent) : nil
    end

    def to_s(io : IO)
      save_ctx = LibXML.xmlSaveToIO(
        ->(ctx, buffer, len) {
          Box(IO).unbox(ctx).write Slice.new(buffer, len)
          len
        },
        ->(ctx) {
          Box(IO).unbox(ctx).flush
          0
        },
        Box(IO).box(io),
        nil,
        0)
      LibXML.xmlSaveTree(save_ctx, self)
      LibXML.xmlSaveClose(save_ctx)
      io
    end

    def type
      @node.value.type
    end

    def [](attribute : String)
      attributes[attribute].content
    end

    def []?(attribute : String)
      attributes[attribute]?.try &.content
    end

    def ==(other : Node)
      @node == other.@node
    end

    def to_unsafe
      @node as LibXML::Node*
    end
  end
end
