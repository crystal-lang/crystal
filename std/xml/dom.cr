require "reader"

module Xml
  class Node
    attr_accessor :name
    attr_accessor :parent_node
    attr_accessor :child_nodes
    attr_accessor :value

    def initialize
      @child_nodes = [] of Node
    end

    def append_child(node)
      @child_nodes << node
    end
  end

  class Element < Node
    def to_s
      if child_nodes.count == 0
        "<#{name}/>"
      else
        String.build do |str|
          str << "<#{name}>"
          child_nodes.each do |child|
            str << child.to_s
          end
          str << "</#{name}>"
        end
      end
    end
  end

  class Text < Node
    def to_s
      value || ""
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

    def to_s
      child_nodes.first.to_s
    end
  end

end
