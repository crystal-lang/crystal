require "./reader"

module XML
  def self.parse(string_or_io)
    Document.parse(string_or_io)
  end

  class Node
    property :name
    property :parent_node
    property :value

    def initialize(@parent_node = nil)
    end

    def child_nodes
      @child_nodes ||= [] of Node
    end

    def has_child_nodes?
      if child_nodes = @child_nodes
        !child_nodes.empty?
      else
        false
      end
    end

    def attributes
      @attributes ||= Attributes.new
    end

    def has_attributes?
      if attributes = @attributes
        !attributes.empty?
      else
        false
      end
    end

    def inner_text
      @child_nodes.try(&.join) || ""
    end
  end

  class Element < Node
    def initialize(@name, parent_node = nil)
      super(parent_node)
    end

    def to_s(io)
      io << "<"
      io << name
      if has_attributes?
        attributes.each do |attribute|
          io << ' '
          io << attribute
        end
      end
      if has_child_nodes?
        io << ">"
        child_nodes.each &.to_s(io)
        io << "</"
        io << name
        io << ">"
      else
        io << "/>"
      end
    end

    private def append_attributes(io)
    end
  end

  class Text < Node
    def initialize(@value, parent_node = nil)
      super(parent_node)
    end

    def to_s(io)
      io << @value
    end
  end

  class Attributes < Array(Attribute)
    def [](name : String)
      attribute = find &.name.==(name)
      if attribute
        attribute.value
      else
        raise MissingKey.new "missing attribute: #{name}"
      end
    end

    def []?(name : String)
      find(&.name.==(name)).try &.value
    end
  end

  class Attribute < Node
    def initialize(@name, @value, parent_node = nil)
      super(parent_node)
    end

    def to_s(io)
      io << @name
      io << %(=")
      io << @value
      io << '"'
    end
  end

  class Document < Node
    def self.parse(io : IO)
      parse(Reader.new(io))
    end

    def self.parse(str : String)
      parse(Reader.new(str))
    end

    def self.parse(reader : Reader)
      doc = Document.new
      current = doc

      while reader.read
        case reader.node_type
        when Type::Element
          elem = Element.new(reader.name, parent_node: current)
          current.child_nodes << elem
          current = elem unless reader.is_empty_element?

          if reader.has_attributes?
            if reader.move_to_first_attribute
              elem.attributes << read_attribute(reader, current)
              while reader.move_to_next_attribute
                elem.attributes << read_attribute(reader, current)
              end
            end
          end
        when Type::EndElement
          parent = current.parent_node
          if parent
            current = parent
          else
            raise "Invalid end element"
          end
        when Type::Text
          text = Text.new(reader.value, current)
          current.child_nodes << text
        end
      end

      doc
    end

    private def self.read_attribute(reader, parent_node)
      Attribute.new(reader.name, reader.value, parent_node)
    end

    def to_s(io)
      io << "<?xml version='1.0' encoding='UTF-8'?>"
      child_nodes.first.to_s(io)
    end
  end
end
