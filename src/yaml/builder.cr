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
#     yaml.scalar "bar"
#     yaml.mapping do
#       yaml.scalar "baz"
#       yaml.scalar "qux"
#     end
#   end
# end
# string # => "---\nfoo:\n- 1\n- 2\nbar:\n  baz: qux\n"
# ```
class YAML::Builder
  @box : Void*

  # By default the maximum nesting of sequences/mappings is 99. Nesting more
  # than this will result in a YAML::Error. Changing the value of this property
  # allows more/less nesting.
  property max_nesting = 99

  # Creates a `YAML::Builder` that will write to the given `IO`.
  def initialize(@io : IO)
    @box = Box.box(io)
    @emitter = Pointer(Void).malloc(LibYAML::EMITTER_SIZE).as(LibYAML::Emitter*)
    @event = LibYAML::Event.new
    @closed = false
    @nesting = 0
    LibYAML.yaml_emitter_initialize(@emitter)
    LibYAML.yaml_emitter_set_unicode(@emitter, 1)
    LibYAML.yaml_emitter_set_output(@emitter, ->(data, buffer, size) {
      data_io = Box(IO).unbox(data)
      data_io.write_string(Slice.new(buffer, size))
      1
    }, @box)
  end

  # Creates a `YAML::Builder` that writes to *io* and yields it to the block.
  #
  # After returning from the block the builder is closed.
  def self.build(io : IO, & : self ->) : Nil
    builder = new(io)
    yield builder ensure builder.close
  end

  # Starts a YAML stream.
  def start_stream
    emit stream_start, LibYAML::Encoding::UTF8
  end

  # Ends a YAML stream.
  def end_stream : Nil
    emit stream_end
    flush
  end

  # Starts a YAML stream, invokes the block, and ends it.
  def stream(&)
    start_stream
    yield.tap { end_stream }
  end

  # Starts a document.
  #
  # If *implicit_start_indicator* is true, skips printing the document start
  # indicator (`---`) if this is the first document in the stream.
  def start_document(*, implicit_start_indicator : Bool = false)
    emit document_start, nil, nil, nil, implicit_start_indicator.to_unsafe
  end

  # Ends a document.
  def end_document
    emit document_end, 1
  end

  # Starts a document, invokes the block, and then ends it.
  #
  # If *implicit_start_indicator* is true, skips printing the document start
  # indicator (`---`) if this is the first document in the stream.
  def document(*, implicit_start_indicator : Bool = false, &)
    start_document(implicit_start_indicator: implicit_start_indicator)
    yield.tap { end_document }
  end

  # Emits a scalar value.
  def scalar(value, anchor : String? = nil, tag : String? = nil, style : YAML::ScalarStyle = YAML::ScalarStyle::ANY)
    string = value.to_s
    implicit = tag ? 0 : 1
    emit scalar, get_anchor(anchor), string_to_unsafe(tag), string, string.bytesize, implicit, implicit, style
  end

  # Starts a sequence.
  def start_sequence(anchor : String? = nil, tag : String? = nil, style : YAML::SequenceStyle = YAML::SequenceStyle::ANY) : Nil
    implicit = tag ? 0 : 1
    emit sequence_start, get_anchor(anchor), string_to_unsafe(tag), implicit, style
    increase_nesting
  end

  # Ends a sequence.
  def end_sequence : Nil
    emit sequence_end
    decrease_nesting
  end

  # Starts a sequence, invokes the block, and the ends it.
  def sequence(anchor : String? = nil, tag : String? = nil, style : YAML::SequenceStyle = YAML::SequenceStyle::ANY, &)
    start_sequence(anchor, tag, style)
    yield.tap { end_sequence }
  end

  # Starts a mapping.
  def start_mapping(anchor : String? = nil, tag : String? = nil, style : YAML::MappingStyle = YAML::MappingStyle::ANY) : Nil
    implicit = tag ? 0 : 1
    emit mapping_start, get_anchor(anchor), string_to_unsafe(tag), implicit, style
    increase_nesting
  end

  # Ends a mapping.
  def end_mapping : Nil
    emit mapping_end
    decrease_nesting
  end

  # Starts a mapping, invokes the block, and then ends it.
  def mapping(anchor : String? = nil, tag : String? = nil, style : YAML::MappingStyle = YAML::MappingStyle::ANY, &)
    start_mapping(anchor, tag, style)
    yield.tap { end_mapping }
  end

  # Emits an alias to the given *anchor*.
  #
  # ```
  # require "yaml"
  #
  # yaml = YAML.build do |builder|
  #   builder.mapping do
  #     builder.scalar "key"
  #     builder.alias "example"
  #   end
  # end
  #
  # yaml # => "---\nkey: *example\n"
  # ```
  def alias(anchor : String) : Nil
    LibYAML.yaml_alias_event_initialize(pointerof(@event), anchor)
    yaml_emit("alias")
  end

  # Emits the scalar `"<<"` followed by an alias to the given *anchor*.
  #
  # See [YAML Merge](https://yaml.org/type/merge.html).
  #
  # ```
  # require "yaml"
  #
  # yaml = YAML.build do |builder|
  #   builder.mapping do
  #     builder.merge "development"
  #   end
  # end
  #
  # yaml # => "---\n<<: *development\n"
  # ```
  def merge(anchor : String) : Nil
    self.scalar "<<"
    self.alias anchor
  end

  # Flushes any pending data to the underlying `IO`.
  def flush
    LibYAML.yaml_emitter_flush(@emitter)

    @io.flush
  end

  def finalize
    return if @closed
    LibYAML.yaml_emitter_delete(@emitter)
  end

  # Closes the builder, freeing up resources.
  def close : Nil
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
    LibYAML.yaml_{{ event_name }}_event_initialize(pointerof(@event), {{ args.splat }})
    yaml_emit({{ event_name.stringify }})
  end

  private def yaml_emit(event_name)
    ret = LibYAML.yaml_emitter_emit(@emitter, pointerof(@event))
    if ret != 1
      raise YAML::Error.new(build_libyaml_message(event_name))
    end
  end

  private def build_libyaml_message(event_name)
    problem = @emitter.value.problem
    strlen = LibC.strlen(problem)
    String.build(event_name.bytesize + strlen + 16) do |io|
      io << "Error emitting " << event_name << ": "
      io.write Slice.new(problem, strlen)
    end
  end

  private def increase_nesting
    @nesting += 1
    if @nesting > @max_nesting
      raise YAML::Error.new("Nesting of #{@nesting} is too deep")
    end
  end

  private def decrease_nesting
    @nesting -= 1
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
  def self.build(&)
    String.build do |str|
      build(str) do |yaml|
        yield yaml
      end
    end
  end

  # Writes YAML into the given `IO`. A `YAML::Builder` is yielded to the block.
  def self.build(io : IO, &) : Nil
    YAML::Builder.build(io) do |yaml|
      yaml.stream do
        yaml.document do
          yield yaml
        end
      end
    end
  end
end
