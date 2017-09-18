# :nodoc:
abstract class YAML::Parser
  def initialize(content : String | IO)
    @pull_parser = PullParser.new(content)
  end

  def self.new(content)
    parser = new(content)
    yield parser ensure parser.close
  end

  abstract def new_documents
  abstract def new_document
  abstract def new_sequence
  abstract def new_mapping
  abstract def new_scalar
  abstract def put_anchor(anchor, value)
  abstract def get_anchor(anchor)

  def end_value(value)
  end

  def process_tag(tag, &block)
  end

  protected def cast_value(value)
    value
  end

  protected def cast_document(document)
    document
  end

  # Deserializes multiple YAML document.
  def parse_all
    documents = new_documents

    @pull_parser.read_next
    loop do
      case @pull_parser.kind
      when .stream_end?
        return documents
      when .document_start?
        documents << cast_value(parse_document)
      else
        unexpected_event
      end
    end
  end

  # Deserializes a YAML document.
  def parse
    @pull_parser.read_next

    document = new_document

    case @pull_parser.kind
    when .stream_end?
    when .document_start?
      parse_document(document)
    else
      unexpected_event
    end

    cast_value(cast_document(document))
  end

  private def parse_document
    document = new_document
    parse_document(document)
    cast_document(document)
  end

  private def parse_document(document)
    @pull_parser.read_next
    document << parse_node
    end_value(document)
    @pull_parser.read_document_end
  end

  protected def parse_node
    tag = @pull_parser.tag
    if tag
      process_tag(tag) do |value|
        return value
      end
    end

    case @pull_parser.kind
    when .scalar?
      parse_scalar
    when .alias?
      parse_alias
    when .sequence_start?
      parse_sequence
    when .mapping_start?
      parse_mapping
    else
      unexpected_event
    end
  end

  protected def parse_scalar
    value = anchor(@pull_parser.anchor, new_scalar)
    @pull_parser.read_next
    value
  end

  protected def parse_alias
    value = get_anchor(@pull_parser.anchor.not_nil!)
    @pull_parser.read_next
    value
  end

  protected def parse_sequence
    sequence = anchor new_sequence

    parse_sequence(sequence) do
      sequence << parse_node
    end

    sequence
  end

  protected def parse_sequence(sequence)
    @pull_parser.read_sequence_start

    until @pull_parser.kind.sequence_end?
      yield
    end

    end_value(sequence)

    @pull_parser.read_next
  end

  protected def parse_mapping
    mapping = anchor new_mapping

    parse_mapping(mapping) do
      mapping[parse_node] = parse_node
    end

    mapping
  end

  protected def parse_mapping(mapping)
    @pull_parser.read_mapping_start

    until @pull_parser.kind.mapping_end?
      yield
    end

    end_value(mapping)

    @pull_parser.read_next
  end

  # Closes this parser, freeing up resources.
  def close
    @pull_parser.close
  end

  private def anchor(anchor, value)
    put_anchor(anchor, value) if anchor
    value
  end

  private def anchor(value)
    anchor(@pull_parser.anchor, value)
  end

  private def unexpected_event
    raise "Unexpected event: #{@pull_parser.kind}"
  end

  private def raise(msg)
    @pull_parser.raise(msg)
  end
end
