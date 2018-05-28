module YAML::Nodes
  # Abstract class of all YAML tree nodes.
  abstract class Node
    # The optional tag of a node.
    property tag : String?

    # The optional anchor of a node.
    property anchor : String?

    # The line where this node starts.
    property start_line = 0

    # The column where this node starts.
    property start_column = 0

    # The line where this node ends.
    property end_line = 0

    # The column where this node ends.
    property end_column = 0

    # Returns a tuple of `start_line` and `start_column`.
    def location : {Int32, Int32}
      {start_line, start_column}
    end

    # Raises a `YAML::ParseException` with the given message
    # located at this node's `location`.
    def raise(message)
      ::raise YAML::ParseException.new(message, *location)
    end
  end

  # A YAML document.
  class Document < Node
    # The nodes inside this document.
    #
    # A document can hold at most one node.
    getter nodes = [] of Node

    # Appends a node to this document. Raises if more
    # than one node is appended.
    def <<(node)
      if nodes.empty?
        nodes << node
      else
        raise ArgumentError.new("Attempted to append more than one node")
      end
    end

    def to_yaml(builder : YAML::Builder)
      nodes.each &.to_yaml(builder)
    end
  end

  # A scalar value.
  class Scalar < Node
    # The style of this scalar.
    property style : ScalarStyle = ScalarStyle::ANY

    # The value of this scalar.
    property value : String

    # Creates a scalar with the given *value*.
    def initialize(@value : String)
    end

    def to_yaml(builder : YAML::Builder)
      builder.scalar(value, anchor, tag, style)
    end
  end

  # A sequence of nodes.
  class Sequence < Node
    include Enumerable(Node)

    # The nodes in this sequence.
    getter nodes = [] of Node

    # The style of this sequence.
    property style : SequenceStyle = SequenceStyle::ANY

    # Appends a node into this sequence.
    def <<(node)
      @nodes << node
    end

    def each
      @nodes.each do |node|
        yield node
      end
    end

    def to_yaml(builder : YAML::Builder)
      builder.sequence(anchor, tag, style) do
        each &.to_yaml(builder)
      end
    end
  end

  # A mapping of nodes.
  class Mapping < Node
    property style : MappingStyle = MappingStyle::ANY

    # The nodes inside this mapping, stored linearly
    # as key1 - value1 - key2 - value2 - etc.
    getter nodes = [] of Node

    # Appends two nodes into this mapping.
    def []=(key, value)
      @nodes << key << value
    end

    # Appends a single node into this mapping.
    def <<(node)
      @nodes << node
    end

    # Yields each key-value pair in this mapping.
    def each
      0.step(by: 2, to: @nodes.size - 1) do |i|
        yield({@nodes[i], @nodes[i + 1]})
      end
    end

    def to_yaml(builder : YAML::Builder)
      builder.mapping(anchor, tag, style) do
        each do |key, value|
          key.to_yaml(builder)
          value.to_yaml(builder)
        end
      end
    end
  end

  # An alias.
  class Alias < Node
    # The node this alias points to.
    # This is set by `YAML::Nodes.parse`, and is `nil` by default.
    property value : Node?

    # Creates an alias with tha given *anchor*.
    def initialize(@anchor : String)
    end

    def to_yaml(builder : YAML::Builder)
      builder.alias(anchor.not_nil!)
    end
  end
end
