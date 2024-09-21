# :nodoc:
class YAML::Nodes::Parser < YAML::Parser
  def initialize(content : String | IO)
    super
    @anchors = {} of String => Node
  end

  def self.new(content, &)
    parser = new(content)
    yield parser ensure parser.close
  end

  def new_documents
    [] of Array(Node)
  end

  def new_document : YAML::Nodes::Document
    Document.new
  end

  def new_sequence : YAML::Nodes::Sequence
    sequence = Sequence.new
    set_common_properties(sequence)
    sequence.style = @pull_parser.sequence_style
    sequence
  end

  def new_mapping : YAML::Nodes::Mapping
    mapping = Mapping.new
    set_common_properties(mapping)
    mapping.style = @pull_parser.mapping_style
    mapping
  end

  def new_scalar : YAML::Nodes::Scalar
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

  def end_value(node) : Nil
    node.end_line = @pull_parser.end_line.to_i
    node.end_column = @pull_parser.end_column.to_i
  end

  def put_anchor(anchor, value)
    @anchors[anchor] = value
  end

  def get_anchor(anchor) : YAML::Nodes::Alias
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

  def add_to_documents(documents, document)
    documents << document
  end

  def add_to_document(document, node) : Nil
    document << node
  end

  def add_to_sequence(sequence, node) : Nil
    sequence << node
  end

  def add_to_mapping(mapping, key, value) : Nil
    mapping[key] = value
  end
end
