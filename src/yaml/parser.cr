class Yaml::Parser
  def initialize(content)
    @parser = Pointer(Void).malloc(LibYaml::PARSER_SIZE) as LibYaml::Parser*
    @event = LibYaml::Event.new
    @anchors = {} of String => Yaml::Type

    LibYaml.yaml_parser_initialize(@parser)
    LibYaml.yaml_parser_set_input_string(@parser, content, content.bytesize)

    next_event
    raise "Expected STREAM_START" unless @event.type == LibYaml::EventType::STREAM_START
  end

  def close
    LibYaml.yaml_parser_delete(@parser)
    LibYaml.yaml_event_delete(pointerof(@event))
  end

  def parse_all
    documents = [] of Yaml::Type
    loop do
      next_event
      case @event.type
      when LibYaml::EventType::STREAM_END
        return documents
      when LibYaml::EventType::DOCUMENT_START
        documents << parse_document
      else
        raise "Unexpected event: #{@event.type}"
      end
    end
  end

  def parse
    next_event
    case @event.type
    when LibYaml::EventType::STREAM_END
      nil
    when LibYaml::EventType::DOCUMENT_START
      parse_document
    else
      raise "Unexpected event: #{@event.type}"
    end
  end

  def parse_document
    next_event
    value = parse_node
    next_event
    raise "Expected DOCUMENT_END" unless @event.type == LibYaml::EventType::DOCUMENT_END
    value
  end

  def parse_node
    case @event.type
    when LibYaml::EventType::SCALAR
      String.new(@event.data.scalar.value).tap do |scalar|
        anchor scalar, &.scalar
      end
    when LibYaml::EventType::ALIAS
      @anchors[String.new(@event.data.alias.anchor)]
    when LibYaml::EventType::SEQUENCE_START
      parse_sequence
    when LibYaml::EventType::MAPPING_START
      parse_mapping
    else
      raise "Unexpected event #{event_to_s(@event.type)}"
    end
  end

  def parse_sequence
    sequence = [] of Yaml::Type
    anchor sequence, &.sequence_start

    loop do
      next_event
      case @event.type
      when LibYaml::EventType::SEQUENCE_END
        return sequence
      else
        sequence << parse_node
      end
    end
  end

  def parse_mapping
    mapping = {} of Yaml::Type => Yaml::Type
    loop do
      next_event
      case @event.type
      when LibYaml::EventType::MAPPING_END
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
    when LibYaml::EventType::NONE then "NONE"
    when LibYaml::EventType::STREAM_START then "STREAM_START"
    when LibYaml::EventType::STREAM_END then "STREAM_END"
    when LibYaml::EventType::DOCUMENT_START then "DOCUMENT_START"
    when LibYaml::EventType::DOCUMENT_END then "DOCUMENT_END"
    when LibYaml::EventType::ALIAS then "ALIAS"
    when LibYaml::EventType::SCALAR then "SCALAR"
    when LibYaml::EventType::SEQUENCE_START then "SEQUENCE_START"
    when LibYaml::EventType::SEQUENCE_END then "SEQUENCE_END"
    when LibYaml::EventType::MAPPING_START then "MAPPING_START"
    when LibYaml::EventType::MAPPING_END then "MAPPING_END"
    end
  end

  def next_event
    LibYaml.yaml_event_delete(pointerof(@event))
    LibYaml.yaml_parser_parse(@parser, pointerof(@event))
  end
end
