class YAML::Parser
  def initialize(content)
    @pull_parser = PullParser.new(content)
    @anchors = {} of String => YAML::Type
  end

  def close
    @pull_parser.close
  end

  def parse_all
    documents = [] of YAML::Any
    loop do
      case @pull_parser.read_next
      when EventKind::STREAM_END
        return documents
      when EventKind::DOCUMENT_START
        documents << YAML::Any.new(parse_document)
      else
        unexpected_event
      end
    end
  end

  def parse
    value = case @pull_parser.read_next
            when EventKind::STREAM_END
              nil
            when EventKind::DOCUMENT_START
              parse_document
            else
              unexpected_event
            end
    YAML::Any.new(value)
  end

  def parse_document
    @pull_parser.read_next
    value = parse_node
    unless @pull_parser.read_next == EventKind::DOCUMENT_END
      raise "Expected DOCUMENT_END"
    end
    value
  end

  def parse_node
    case @pull_parser.kind
    when EventKind::SCALAR
      anchor @pull_parser.value, @pull_parser.scalar_anchor
    when EventKind::ALIAS
      @anchors[@pull_parser.alias_anchor]
    when EventKind::SEQUENCE_START
      parse_sequence
    when EventKind::MAPPING_START
      parse_mapping
    else
      unexpected_event
    end
  end

  def parse_sequence
    sequence = [] of YAML::Type
    anchor sequence, @pull_parser.sequence_anchor

    loop do
      case @pull_parser.read_next
      when EventKind::SEQUENCE_END
        return sequence
      else
        sequence << parse_node
      end
    end
  end

  def parse_mapping
    mapping = {} of YAML::Type => YAML::Type
    anchor mapping, @pull_parser.mapping_anchor

    loop do
      case @pull_parser.read_next
      when EventKind::MAPPING_END
        return mapping
      else
        key = parse_node
        @pull_parser.read_next
        value = parse_node
        mapping[key] = value
      end
    end
  end

  def anchor(value, anchor)
    @anchors[anchor] = value if anchor
    value
  end

  private def unexpected_event
    raise "Unexpected event: #{@pull_parser.kind}"
  end

  private def raise(msg)
    ::raise ParseException.new(msg, @pull_parser.line_number, @pull_parser.column_number)
  end
end
