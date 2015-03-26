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

    def first_element_child
      child = @node.value.children
      while child
        if child.value.type == XML::Type::Element
          return Node.from_ptr(child)
        end
        child = child.value.next
      end
      nil
    end

    def inspect(io)
      io << "#<" << self.class.name << ":0x"
      object_id.to_s(16, io)

      io << " name="
      name.inspect(io)

      unless self.is_a?(Attribute)
        children = self.children
        unless children.empty?
          io << " children="
          children.inspect(io)
        end

        attributes = self.attributes
        unless attributes.empty?
          io << " attributes="
          attributes.inspect(io)
        end
      end

      io << ">"
      io
    end

    def next
      next_node = @node.value.next
      next_node ? Node.from_ptr(next_node) : nil
    end

    def next_sibling
      self.next
    end

    def next_element
      next_node = @node.value.next
      while next_node
        if next_node.value.type == XML::Type::Element
          return Node.from_ptr(next_node)
        end
        next_node = next_node.value.next
      end
      nil
    end

    def name
      String.new(@node.value.name)
    end

    def parent
      parent = @node.value.parent
      parent ? Node.from_ptr(parent) : nil
    end

    def previous
      prev_node = @node.value.prev
      prev_node ? Node.from_ptr(prev_node) : nil
    end

    def previous_element
      prev_node = @node.value.prev
      while prev_node
        if prev_node.value.type == XML::Type::Element
          return Node.from_ptr(prev_node)
        end
        prev_node = prev_node.value.prev
      end
      nil
    end

    def previous_sibling
      previous
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

    def to_unsafe
      @node as LibXML::Node*
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
  end
end
