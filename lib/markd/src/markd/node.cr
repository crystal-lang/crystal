module Markd
  class Node
    # Node Type
    enum Type
      Document
      Paragraph
      Text
      Strong
      Emphasis
      Link
      Image
      Heading
      List
      Item
      BlockQuote
      ThematicBreak
      Code
      CodeBlock
      HTMLBlock
      HTMLInline
      LineBreak
      SoftBreak

      CustomInLine
      CustomBlock

      def container?
        CONTAINER_TYPES.includes?(self)
      end
    end

    CONTAINER_TYPES = {
      Type::Document,
      Type::Paragraph,
      Type::Strong,
      Type::Emphasis,
      Type::Link,
      Type::Image,
      Type::Heading,
      Type::List,
      Type::Item,
      Type::BlockQuote,
      Type::CustomInLine,
      Type::CustomBlock,
    }

    alias DataValue = String | Int32 | Bool
    alias DataType = Hash(String, DataValue)

    property type : Type

    property(data) { {} of String => DataValue }
    property source_pos = { {1, 1}, {0, 0} }
    property text = ""
    property? open = true
    property? fenced = false
    property fence_language = ""
    property fence_char = ""
    property fence_length = 0
    property fence_offset = 0
    property? last_line_blank = false

    property! parent : Node?
    property! first_child : Node?
    property! last_child : Node?
    property! prev : Node?
    property! next : Node?

    def initialize(@type)
    end

    def append_child(child : Node)
      child.unlink
      child.parent = self

      if last = last_child?
        last.next = child
        child.prev = last
        @last_child = child
      else
        @first_child = child
        @last_child = child
      end
    end

    def insert_after(sibling : Node)
      sibling.unlink

      if nxt = next?
        nxt.prev = sibling
      elsif parent = parent?
        parent.last_child = sibling
      end
      sibling.next = nxt

      sibling.prev = self
      @next = sibling
      sibling.parent = parent?
    end

    def unlink
      if prev = prev?
        prev.next = next?
      elsif parent = parent?
        parent.first_child = next?
      end

      if nxt = next?
        nxt.prev = prev?
      elsif parent = parent?
        parent.last_child = prev?
      end

      @parent = nil
      @next = nil
      @prev = nil
    end

    def walker
      Walker.new(self)
    end

    def to_s(io : IO)
      io << "#<" << {{@type.name.id.stringify}} << ":0x"
      object_id.to_s(16, io)
      io << " @type=" << @type
      io << " @parent=" << @parent if @parent
      io << " @next=" << @next if @next

      data = @data
      io << " @data=" << data if data && !data.empty?

      io << ">"
      nil
    end

    private class Walker
      def initialize(@root : Node)
        @current = @root
        @entering = true
      end

      def next
        current = @current
        return unless current

        entering = @entering

        if entering && current.type.container?
          if first_child = current.first_child?
            @current = first_child
            @entering = true
          else
            @entering = false
          end
        elsif current == @root
          @current = nil
        elsif nxt = current.next?
          @current = current.next?
          @entering = true
        else
          @current = current.parent?
          @entering = false
        end

        return current, entering
      end

      def resume_at(node : Node, entering : Bool)
        @current = node
        @entering = entering
      end
    end
  end
end
