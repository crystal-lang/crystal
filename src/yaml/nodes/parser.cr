# :nodoc:
class YAML::Nodes::Parser < YAML::Parser
  def initialize(content : String | IO)
    super
    @anchors = {} of String => Node
  end

  def self.new(content)
    parser = new(content)
    yield parser ensure parser.close
  end

  def new_documents
    [] of Array(Node)
  end

  def new_document
    Document.new
  end

  def new_sequence
    sequence = Sequence.new
    set_common_properties(sequence)
    sequence.style = @pull_parser.sequence_style
    sequence
  end

  def new_mapping
    mapping = Mapping.new
    set_common_properties(mapping)
    mapping.style = @pull_parser.mapping_style
    mapping
  end

  def new_scalar
    scalar = Scalar.new(@pull_parser.value)
    set_common_properties(scalar)
    scalar.style = @pull_parser.scalar_style
    scalar
  end

  private def set_common_properties(node)
    node.tag = @pull_parser.tag
    node.anchor = @pull_parser.anchor
    node.start_line = @pull_parser.start_line.to_i
    node.start_column = @pull_parser.start_column.to_i
  end

  def end_value(node)
    node.end_line = @pull_parser.end_line.to_i
    node.end_column = @pull_parser.end_column.to_i
  end

  def put_anchor(anchor, value)
    @anchors[anchor] = value
  end

  def get_anchor(anchor)
    value = @anchors.fetch(anchor) do
      @pull_parser.raise("Unknown anchor '#{anchor}'")
    end
    node = Alias.new(anchor)
    node.value = value
    set_common_properties(node)
    node
  end

  def process_tag(tag, &block)
  end
end
