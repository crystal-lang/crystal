require "./enums"

# Supported library versions:
#
# * libyaml
#
# See https://crystal-lang.org/reference/man/required_libraries.html#other-stdlib-libraries
@[Link("yaml", pkg_config: "yaml-0.1")]
{% if compare_versions(Crystal::VERSION, "1.11.0-dev") >= 0 %}
  @[Link(dll: "yaml.dll")]
{% end %}
lib LibYAML
  alias Int = LibC::Int

  # To avoid mapping the whole parser and emitter structs,
  # we computed their size with C programs. We then allocate
  # the necessary memory and cast to the Parser and Emitter
  # structs if necessary, where we mapped only some fields
  # we are interested in.
  {% if flag?(:x86_64) || flag?(:aarch64) %}
    PARSER_SIZE  = 480
    EMITTER_SIZE = 432
  {% else %}
    PARSER_SIZE  = 248
    EMITTER_SIZE = 264
  {% end %}

  enum Encoding
    Any
    UTF8
    UTF16LE
    UTF16BE
  end

  struct Parser
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
    style : YAML::ScalarStyle
  end

  struct SequenceStartEvent
    anchor : UInt8*
    tag : UInt8*
    implicit : Int
    style : YAML::SequenceStyle
  end

  struct MappingStartEvent
    anchor : UInt8*
    tag : UInt8*
    implicit : Int
    style : YAML::MappingStyle
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

  struct Mark
    index : LibC::SizeT
    line : LibC::SizeT
    column : LibC::SizeT
  end

  struct Event
    type : YAML::EventKind
    data : EventData
    start_mark : Mark
    end_mark : Mark
  end

  alias ReadHandler = Void*, LibC::UChar*, LibC::SizeT, LibC::SizeT* -> Int

  struct Emitter
    error : Int
  end

  alias WriteHandler = (Void*, LibC::Char*, LibC::SizeT) -> Int

  fun yaml_parser_initialize(parser : Parser*) : Int
  fun yaml_parser_set_input(parser : Parser*, handler : ReadHandler, data : Void*)
  fun yaml_parser_set_input_string(parser : Parser*, input : UInt8*, length : LibC::SizeT)
  fun yaml_parser_parse(parser : Parser*, event : Event*) : Int
  fun yaml_parser_delete(parser : Parser*)
  fun yaml_event_delete(event : Event*)

  fun yaml_emitter_initialize(emitter : Emitter*) : Int
  fun yaml_emitter_set_output(emitter : Emitter*, handler : WriteHandler, data : Void*)
  fun yaml_emitter_open(emitter : Emitter*) : Int
  fun yaml_stream_start_event_initialize(event : Event*, encoding : Encoding) : Int
  fun yaml_stream_end_event_initialize(event : Event*) : Int
  fun yaml_document_start_event_initialize(event : Event*, version : VersionDirective*, tag_start : TagDirective*, tag_end : TagDirective*, implicit : Int) : Int
  fun yaml_document_end_event_initialize(event : Event*, implicit : Int) : Int
  fun yaml_scalar_event_initialize(event : Event*, anchor : LibC::Char*,
                                   tag : LibC::Char*, value : LibC::Char*, length : Int,
                                   plain_implicit : Int, quoted_implicit : Int, style : YAML::ScalarStyle) : Int
  fun yaml_alias_event_initialize(event : Event*, anchor : LibC::Char*) : Int
  fun yaml_sequence_start_event_initialize(event : Event*, anchor : LibC::Char*, tag : LibC::Char*, implicit : Int, style : YAML::SequenceStyle) : Int
  fun yaml_sequence_end_event_initialize(event : Event*)
  fun yaml_mapping_start_event_initialize(event : Event*, anchor : LibC::Char*, tag : LibC::Char*, implicit : Int, style : YAML::MappingStyle) : Int
  fun yaml_mapping_end_event_initialize(event : Event*) : Int
  fun yaml_emitter_emit(emitter : Emitter*, event : Event*) : Int
  fun yaml_emitter_delete(emitter : Emitter*)
  fun yaml_emitter_flush(emitter : Emitter*) : Int
  fun yaml_emitter_set_unicode(emitter : Emitter*, unicode : Int)

  fun yaml_get_version(major : LibC::Int*, minor : LibC::Int*, patch : LibC::Int*)
end
