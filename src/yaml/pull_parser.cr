class YAML::PullParser
  def initialize(content)
    @parser = Pointer(Void).malloc(LibYAML::PARSER_SIZE) as LibYAML::Parser*
    @event = LibYAML::Event.new

    LibYAML.yaml_parser_initialize(@parser)
    LibYAML.yaml_parser_set_input_string(@parser, content, LibC::SizeT.cast(content.bytesize))

    read_next
    raise "Expected STREAM_START" unless @event.type == LibYAML::EventType::STREAM_START
  end

  def kind
    @event.type
  end

  def value
    String.new(@event.data.scalar.value)
  end

  def anchor
    case kind
    when LibYAML::EventType::SCALAR
      scalar_anchor
    when LibYAML::EventType::SEQUENCE_START
      sequence_anchor
    when LibYAML::EventType::MAPPING_START
      mapping_anchor
    else
      nil
    end
  end

  def scalar_anchor
    read_anchor @event.data.scalar.anchor
  end

  def sequence_anchor
    read_anchor @event.data.sequence_start.anchor
  end

  def mapping_anchor
    read_anchor @event.data.mapping_start.anchor
  end

  def alias_anchor
    read_anchor @event.data.alias.anchor
  end

  def read_next
    LibYAML.yaml_event_delete(pointerof(@event))
    LibYAML.yaml_parser_parse(@parser, pointerof(@event))
    kind
  end

  def close
    LibYAML.yaml_parser_delete(@parser)
    LibYAML.yaml_event_delete(pointerof(@event))
  end

  private def read_anchor(anchor)
    anchor ? String.new(anchor) : nil
  end
end
