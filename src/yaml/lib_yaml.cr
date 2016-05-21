@[Link("yaml")]
lib LibYAML
  alias Int = LibC::Int

  PARSER_SIZE = 480
  type Parser = Void*

  # The struct of yaml_parser_s is internal, yet some libraries (like Ruby's psych)
  # access some of its data for getting the line/column information of an error.
  # Here we replicate only part of this data. When we need it, we cast a Parser*
  # to this type, so we don't need to have the correct size of the Parser struct,
  # but only define some members at the beginning.
  struct InternalParser
    error : Int
    problem : LibC::Char*
    problem_offset : LibC::SizeT
    problem_value : Int
    problem_mark : Mark
    context : LibC::Char*
    context_mark : Mark
  end

  struct VersionDirective
    major : Int
    minor : Int
  end

  struct TagDirective
    handle : UInt8*
    prefix : UInt8*
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
    implicit : Int
  end

  struct DocumentEndEvent
    implicit : Int
  end

  struct AliasEvent
    anchor : UInt8*
  end

  struct ScalarEvent
    anchor : UInt8*
    tag : UInt8*
    value : UInt8*
    length : LibC::SizeT
    plain_implicit : Int
    quoted_implicit : Int
    style : ScalarStyle
  end

  struct SequenceStartEvent
    anchor : UInt8*
    tag : UInt8*
    implicit : Int
    style : SequenceStyle
  end

  struct MappingStartEvent
    anchor : UInt8*
    tag : UInt8*
    implicit : Int
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
    index : LibC::SizeT
    line : LibC::SizeT
    column : LibC::SizeT
  end

  struct Event
    type : EventType
    data : EventData
    start_mark : Mark
    end_mark : Mark
  end

  fun yaml_parser_initialize(parser : Parser*) : Int
  fun yaml_parser_set_input_string(parser : Parser*, input : UInt8*, length : LibC::SizeT)
  fun yaml_parser_parse(parser : Parser*, event : Event*) : Int
  fun yaml_parser_delete(parser : Parser*)
  fun yaml_event_delete(event : Event*)
end
