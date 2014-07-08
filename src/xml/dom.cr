require "reader"

module Xml
  class Node
    property :name
    property :parent_node
    property :child_nodes
    property :value

    def initialize
      @child_nodes = [] of Node
    end

    def append_child(node)
      @child_nodes << node
    end
  end

  class Element < Node
    def to_s(io)
      if child_nodes.count == 0
        io << "<"
        io << name
        io << "/>"
      else
        io << "<"
        io << name
        io << ">"
        child_nodes.each do |child|
          child.to_s(io)
        end
        io << "</"
        io << name
        io << ">"
      end
    end
  end

  class Text < Node
    def to_s(io)
      (value || "").to_s(io)
    end
  end

  class Document < Node
    def self.parse(str : String)
      doc = Document.new
      reader = Reader.new(str)
      current = doc

      while reader.read
        case reader.node_type
        when :element
          elem = Element.new
          elem.name = reader.name
          elem.parent_node = current
          current.append_child elem
          current = elem unless reader.is_empty_element
        when :end_element
          parent = current.parent_node
          if parent
            current = parent
          else
            raise "Invalid end element"
          end
        when :text
          text = Text.new
          text.value = reader.value
          current.append_child text
        end
      end

      doc
    end

    def to_s(io)
      child_nodes.first.to_s(io)
    end
  end
end
