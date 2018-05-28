# A YAML builder generates valid YAML.
#
# A `YAML::Error` is raised if attempting to generate
# an invalid YAML (for example, if invoking `end_sequence`
# without a matching `start_sequence`)
#
# ```
# require "yaml"
#
# string = YAML.build do |yaml|
#   yaml.mapping do
#     yaml.scalar "foo"
#     yaml.sequence do
#       yaml.scalar 1
#       yaml.scalar 2
#     end
#   end
# end
# string # => "---\nfoo:\n- 1\n- 2\n"
# ```
class YAML::Builder
  @box : Void*

  # Creates a `YAML::Builder` that will write to the given `IO`.
  def initialize(@io : IO)
    @box = Box.box(io)
    @emitter = Pointer(Void).malloc(LibYAML::EMITTER_SIZE).as(LibYAML::Emitter*)
    @event = LibYAML::Event.new
    @closed = false
    LibYAML.yaml_emitter_initialize(@emitter)
    LibYAML.yaml_emitter_set_output(@emitter, ->(data, buffer, size) {
      data_io = Box(IO).unbox(data)
      data_io.write(Slice.new(buffer, size))
      1
    }, @box)
  end

  # Creates a `YAML::Builder` that will write to the given `IO`,
  # invokes the block and closes the builder.
  def self.new(io : IO)
    emitter = new(io)
    yield emitter ensure emitter.close
  end

  # Starts a YAML stream.
  def start_stream
    emit stream_start, LibYAML::Encoding::UTF8
  end

  # Ends a YAML stream.
  def end_stream
    emit stream_end
  end

  # Starts a YAML stream, invokes the block, and ends it.
  def stream
    start_stream
    yield.tap { end_stream }
  end

  # Starts a document.
  def start_document
    emit document_start, nil, nil, nil, 0
  end

  # Ends a document.
  def end_document
    emit document_end, 1
  end

  # Starts a document, invokes the block, and then ends it.
  def document
    start_document
    yield.tap { end_document }
  end

  # Emits a scalar value.
  def scalar(value, anchor : String? = nil, tag : String? = nil, style : YAML::ScalarStyle = YAML::ScalarStyle::ANY)
    string = value.to_s
    implicit = tag ? 0 : 1
    emit scalar, get_anchor(anchor), string_to_unsafe(tag), string, string.bytesize, implicit, implicit, style
  end

  # Starts a sequence.
  def start_sequence(anchor : String? = nil, tag : String? = nil, style : YAML::SequenceStyle = YAML::SequenceStyle::ANY)
    implicit = tag ? 0 : 1
    emit sequence_start, get_anchor(anchor), string_to_unsafe(tag), implicit, style
  end

  # Ends a sequence.
  def end_sequence
    emit sequence_end
  end

  # Starts a sequence, invokes the block, and the ends it.
  def sequence(anchor : String? = nil, tag : String? = nil, style : YAML::SequenceStyle = YAML::SequenceStyle::ANY)
    start_sequence(anchor, tag, style)
    yield.tap { end_sequence }
  end

  # Starts a mapping.
  def start_mapping(anchor : String? = nil, tag : String? = nil, style : YAML::MappingStyle = YAML::MappingStyle::ANY)
    implicit = tag ? 0 : 1
    emit mapping_start, get_anchor(anchor), string_to_unsafe(tag), implicit, style
  end

  # Ends a mapping.
  def end_mapping
    emit mapping_end
  end

  # Starts a mapping, invokes the block, and then ends it.
  def mapping(anchor : String? = nil, tag : String? = nil, style : YAML::MappingStyle = YAML::MappingStyle::ANY)
    start_mapping(anchor, tag, style)
    yield.tap { end_mapping }
  end

  def alias(anchor : String)
    LibYAML.yaml_alias_event_initialize(pointerof(@event), anchor)
    yaml_emit("alias")
  end

  # Flushes any pending data to the underlying `IO`.
  def flush
    LibYAML.yaml_emitter_flush(@emitter)
  end

  def finalize
    return if @closed
    LibYAML.yaml_emitter_delete(@emitter)
  end

  # Closes the builder, freeing up resources.
  def close
    finalize
    @closed = true
  end

  private def get_anchor(anchor)
    string_to_unsafe(anchor)
  end

  private def string_to_unsafe(tag)
    tag.try(&.to_unsafe) || Pointer(UInt8).null
  end

  private macro emit(event_name, *args)
    LibYAML.yaml_{{event_name}}_event_initialize(pointerof(@event), {{*args}})
    yaml_emit({{event_name.stringify}})
  end

  private def yaml_emit(event_name)
    ret = LibYAML.yaml_emitter_emit(@emitter, pointerof(@event))
    if ret != 1
      raise YAML::Error.new("Error emitting #{event_name}")
    end
  end
end

module YAML
  # Returns the resulting String of writing YAML to the yielded `YAML::Builder`.
  #
  # ```
  # require "yaml"
  #
  # string = YAML.build do |yaml|
  #   yaml.mapping do
  #     yaml.scalar "foo"
  #     yaml.sequence do
  #       yaml.scalar 1
  #       yaml.scalar 2
  #     end
  #   end
  # end
  # string # => "---\nfoo:\n- 1\n- 2\n"
  # ```
  def self.build
    String.build do |str|
      build(str) do |yaml|
        yield yaml
      end
    end
  end

  # Writes YAML into the given `IO`. A `YAML::Builder` is yielded to the block.
  def self.build(io : IO)
    YAML::Builder.new(io) do |yaml|
      yaml.stream do
        yaml.document do
          yield yaml
        end
      end
    end
  end
end
