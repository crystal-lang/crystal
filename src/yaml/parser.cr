class YAML::Parser
  def initialize(content)
    @parser = Pointer(Void).malloc(LibYAML::PARSER_SIZE) as LibYAML::Parser*
    @event = LibYAML::Event.new
    @anchors = {} of String => YAML::Type

    LibYAML.yaml_parser_initialize(@parser)
    LibYAML.yaml_parser_set_input_string(@parser, content, content.bytesize)

    next_event
    raise "Expected STREAM_START" unless @event.type == LibYAML::EventType::STREAM_START
  end

  def close
    LibYAML.yaml_parser_delete(@parser)
    LibYAML.yaml_event_delete(pointerof(@event))
  end

  def parse_all
    documents = [] of YAML::Type
    loop do
      next_event
      case @event.type
      when LibYAML::EventType::STREAM_END
        return documents
      when LibYAML::EventType::DOCUMENT_START
        documents << parse_document
      else
        raise "Unexpected event: #{@event.type}"
      end
    end
  end

  def parse
    next_event
    case @event.type
    when LibYAML::EventType::STREAM_END
      nil
    when LibYAML::EventType::DOCUMENT_START
      parse_document
    else
      raise "Unexpected event: #{@event.type}"
    end
  end

  def parse_document
    next_event
    value = parse_node
    next_event
    raise "Expected DOCUMENT_END" unless @event.type == LibYAML::EventType::DOCUMENT_END
    value
  end

  def parse_node
    case @event.type
    when LibYAML::EventType::SCALAR
      String.new(@event.data.scalar.value).tap do |scalar|
        anchor scalar, &.scalar
      end
    when LibYAML::EventType::ALIAS
      @anchors[String.new(@event.data.alias.anchor)]
    when LibYAML::EventType::SEQUENCE_START
      parse_sequence
    when LibYAML::EventType::MAPPING_START
      parse_mapping
    else
      raise "Unexpected event #{event_to_s(@event.type)}"
    end
  end

  def parse_sequence
    sequence = [] of YAML::Type
    anchor sequence, &.sequence_start

    loop do
      next_event
      case @event.type
      when LibYAML::EventType::SEQUENCE_END
        return sequence
      else
        sequence << parse_node
      end
    end
  end

  def parse_mapping
    mapping = {} of YAML::Type => YAML::Type
    loop do
      next_event
      case @event.type
      when LibYAML::EventType::MAPPING_END
        return mapping
      else
        key = parse_node
        next_event
        value = parse_node
        mapping[key] = value
      end
    end
  end

  def anchor(value)
    anchor = yield(@event.data).anchor
    @anchors[String.new(anchor)] = value if anchor
  end

  def event_to_s(event_type)
    case event_type
    when LibYAML::EventType::NONE then "NONE"
    when LibYAML::EventType::STREAM_START then "STREAM_START"
    when LibYAML::EventType::STREAM_END then "STREAM_END"
    when LibYAML::EventType::DOCUMENT_START then "DOCUMENT_START"
    when LibYAML::EventType::DOCUMENT_END then "DOCUMENT_END"
    when LibYAML::EventType::ALIAS then "ALIAS"
    when LibYAML::EventType::SCALAR then "SCALAR"
    when LibYAML::EventType::SEQUENCE_START then "SEQUENCE_START"
    when LibYAML::EventType::SEQUENCE_END then "SEQUENCE_END"
    when LibYAML::EventType::MAPPING_START then "MAPPING_START"
    when LibYAML::EventType::MAPPING_END then "MAPPING_END"
    end
  end

  def next_event
    LibYAML.yaml_event_delete(pointerof(@event))
    LibYAML.yaml_parser_parse(@parser, pointerof(@event))
  end
end
