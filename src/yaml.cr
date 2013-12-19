class Yaml
  def self.load(data)
    parser = YamlParser.new(data)
    begin
      parser.parse
    ensure
      parser.close
    end
  end

  def self.load_all(data)
    parser = YamlParser.new(data)
    begin
      parser.parse_all
    ensure
      parser.close
    end
  end
end

alias YamlType = String | Hash(YamlType, YamlType) | Array(YamlType) | Nil

class YamlParser
  def initialize(content)
    @parser = Pointer(Void).malloc(LibYaml::PARSER_SIZE).as(LibYaml::Parser)
    LibYaml.yaml_parser_initialize(@parser)
    LibYaml.yaml_parser_set_input_string(@parser, content, content.length)

    @event = LibYaml::Event.new
    @anchors = {} of String => YamlType

    next_event
    raise "Expected STREAM_START" unless @event.type == LibYaml::EventType::STREAM_START
  end

  def close
    LibYaml.yaml_parser_delete(@parser)
    LibYaml.yaml_event_delete(addressof(@event))
  end

  def parse_all
    documents = [] of YamlType
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
    sequence = [] of YamlType
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
    mapping = {} of YamlType => YamlType
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
    LibYaml.yaml_event_delete(addressof(@event))
    LibYaml.yaml_parser_parse(@parser, addressof(@event))
  end
end

lib LibYaml("yaml")
  PARSER_SIZE = 480
  type Parser : Void*

  struct VersionDirective
    major : Int32
    minor : Int32
  end

  struct TagDirective
    handle : Char*
    prefix : Char*
  end

  enum ScalarStyle
    ANY
    PLAIN
    SINGLE_QUOTED
    DOUBLE_QUOTED
    LITERAL
    FOLDED
  end

  enum SequenceStyle
    ANY
    BLOCK
    FLOW
  end

  enum MappingStyle
    ANY
    BLOCK
    FLOW
  end

  struct StreamStartEvent
    encoding : Int32
  end

  struct DocumentStartEvent
    version_directive : VersionDirective*
    tag_directive_start : TagDirective*
    tag_directive_end : TagDirective*
    implicit : Int32
  end

  struct DocumentEndEvent
    implicit : Int32
  end

  struct AliasEvent
    anchor : Char*
  end

  struct ScalarEvent
    anchor : Char*
    tag : Char*
    value : Char*
    length : UInt64
    plain_implicit : Int32
    quoted_implicit : Int32
    style : ScalarStyle
  end

  struct SequenceStartEvent
    anchor : Char*
    tag : Char*
    implicit : Int32
    style : SequenceStyle
  end

  struct MappingStartEvent
    anchor : Char*
    tag : Char*
    implicit : Int32
    style : MappingStyle
  end

  union EventData
    stream_start : StreamStartEvent
    document_start : DocumentStartEvent
    document_end : DocumentEndEvent
    alias : AliasEvent
    scalar : ScalarEvent
    sequence_start : SequenceStartEvent
    mapping_start : MappingStartEvent
  end

  enum EventType
    NONE
    STREAM_START
    STREAM_END
    DOCUMENT_START
    DOCUMENT_END
    ALIAS
    SCALAR
    SEQUENCE_START
    SEQUENCE_END
    MAPPING_START
    MAPPING_END
  end

  struct Mark
    index : UInt64
    line : UInt64
    column : UInt64
  end

  struct Event
    type : EventType
    data : EventData
    start_mark : Mark
    end_mark : Mark
  end

  fun yaml_parser_initialize(parser : Parser*) : Int32
  fun yaml_parser_set_input_string(parser : Parser*, input : Char*, length : Int32)
  fun yaml_parser_parse(parser : Parser*, event : Event*) : Int32
  fun yaml_parser_delete(parser : Parser*)
  fun yaml_event_delete(event : Event*)
end
