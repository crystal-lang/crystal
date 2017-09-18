# A pull parser allows parsing a YAML document by events.
#
# When creating an instance, the parser is positioned in
# the first event. To get the event kind invoke `kind`.
# If the event is a scalar you can invoke `value` to get
# its **string** value. Other methods like `tag`, `anchor`
# and `scalar_style` let you inspect other information from events.
#
# Invoking `read_next` reads the next event.
class YAML::PullParser
  protected getter content

  def initialize(@content : String | IO)
    @parser = Pointer(Void).malloc(LibYAML::PARSER_SIZE).as(LibYAML::Parser*)
    @event = LibYAML::Event.new
    @closed = false

    LibYAML.yaml_parser_initialize(@parser)

    if content.is_a?(String)
      LibYAML.yaml_parser_set_input_string(@parser, content, content.bytesize)
    else
      LibYAML.yaml_parser_set_input(@parser, ->(data, buffer, size, size_read) {
        parser = data.as(YAML::PullParser)
        io = parser.content.as(IO)
        slice = Slice.new(buffer, size)
        actual_read_bytes = io.read(slice)
        size_read.value = LibC::SizeT.new(actual_read_bytes)
        LibC::Int.new(1)
      }, self.as(Void*))
    end

    read_next
    raise "Expected STREAM_START" unless kind.stream_start?
  end

  # Creates a parser, yields it to the block, and closes
  # the parser at the end of it.
  def self.new(content)
    parser = new(content)
    yield parser ensure parser.close
  end

  # The current event kind.
  def kind : EventKind
    @event.type
  end

  # Returns the tag associated to the current event, or `nil`
  # if there's no tag.
  def tag : String?
    case kind
    when .mapping_start?
      ptr = @event.data.mapping_start.tag
    when .sequence_start?
      ptr = @event.data.sequence_start.tag
    when .scalar?
      ptr = @event.data.scalar.tag
    end
    ptr ? String.new(ptr) : nil
  end

  # Returns the scalar value, assuming the pull parser
  # is located at a scalar. Raises otherwise.
  def value : String
    expect_kind EventKind::SCALAR

    ptr = @event.data.scalar.value
    ptr ? String.new(ptr, @event.data.scalar.length) : ""
  end

  # Returns the anchor associated to the current event, or `nil`
  # if there's no anchor.
  def anchor
    case kind
    when .scalar?
      read_anchor @event.data.scalar.anchor
    when .sequence_start?
      read_anchor @event.data.sequence_start.anchor
    when .mapping_start?
      read_anchor @event.data.mapping_start.anchor
    when .alias?
      read_anchor @event.data.alias.anchor
    else
      nil
    end
  end

  # Returns the sequence style, assuming the pull parser is located
  # at a sequence begin event. Raises otherwise.
  def sequence_style : SequenceStyle
    expect_kind EventKind::SEQUENCE_START
    @event.data.sequence_start.style
  end

  # Returns the mapping style, assuming the pull parser is located
  # at a mapping begin event. Raises otherwise.
  def mapping_style : MappingStyle
    expect_kind EventKind::MAPPING_START
    @event.data.mapping_start.style
  end

  # Returns the scalar style, assuming the pull parser is located
  # at a scalar event. Raises otherwise.
  def scalar_style : ScalarStyle
    expect_kind EventKind::SCALAR
    @event.data.scalar.style
  end

  # Reads the next event.
  def read_next : EventKind
    LibYAML.yaml_event_delete(pointerof(@event))
    LibYAML.yaml_parser_parse(@parser, pointerof(@event))
    if problem = problem?
      msg = String.new(problem)
      location = {problem_line_number, problem_column_number}
      if context = context?
        context_info = {String.new(context), context_line_number, context_column_number}
      end
      raise msg, *location, context_info
    end
    kind
  end

  # Reads a "stream start" event, yields to the block,
  # and then reads a "stream end" event.
  def read_stream
    read_stream_start
    value = yield
    read_stream_end
    value
  end

  # Reads a "document start" event, yields to the block,
  # and then reads a "document end" event.
  def read_document
    read_document_start
    value = yield
    read_document_end
    value
  end

  # Reads a "sequence start" event, yields to the block,
  # and then reads a "sequence end" event.
  def read_sequence
    read_sequence_start
    value = yield
    read_sequence_end
    value
  end

  # Reads a "mapping start" event, yields to the block,
  # and then reads a "mapping end" event.
  def read_mapping
    read_mapping_start
    value = yield
    read_mapping_end
    value
  end

  # Reads an alias event, returning its anchor.
  def read_alias
    expect_kind EventKind::ALIAS
    anchor = self.anchor
    read_next
    anchor
  end

  # Reads a scalar, returning its value.
  def read_scalar
    expect_kind EventKind::SCALAR
    value = self.value
    read_next
    value
  end

  # Reads a "stream start" event.
  def read_stream_start
    read EventKind::STREAM_START
  end

  # Reads a "stream end" event.
  def read_stream_end
    read EventKind::STREAM_END
  end

  # Reads a "document start" event.
  def read_document_start
    read EventKind::DOCUMENT_START
  end

  # Reads a "document end" event.
  def read_document_end
    read EventKind::DOCUMENT_END
  end

  # Reads a "sequence start" event.
  def read_sequence_start
    read EventKind::SEQUENCE_START
  end

  # Reads a "sequence end" event.
  def read_sequence_end
    read EventKind::SEQUENCE_END
  end

  # Reads a "mapping start" event.
  def read_mapping_start
    read EventKind::MAPPING_START
  end

  # Reads a "mapping end" event.
  def read_mapping_end
    read EventKind::MAPPING_END
  end

  # Reads an expected event kind.
  def read(expected_kind : EventKind) : EventKind
    expect_kind expected_kind
    read_next
  end

  def skip
    case kind
    when .scalar?
      read_next
    when .alias?
      read_next
    when .sequence_start?
      read_next
      until kind.sequence_end?
        skip
      end
      read_next
    when .mapping_start?
      read_next
      until kind.mapping_end?
        skip
        skip
      end
      read_next
    end
  end

  # Note: YAML starts counting from 0, we want to count from 1

  def location
    {start_line, start_column}
  end

  def start_line
    @event.start_mark.line + 1
  end

  def start_column
    @event.start_mark.column + 1
  end

  def end_line
    @event.end_mark.line + 1
  end

  def end_column
    @event.end_mark.column + 1
  end

  private def problem_line_number
    (problem? ? problem_mark?.line : start_line) + 1
  end

  private def problem_column_number
    (problem? ? problem_mark?.column : start_column) + 1
  end

  private def problem_mark?
    @parser.value.problem_mark
  end

  private def problem?
    @parser.value.problem
  end

  private def context?
    @parser.value.context
  end

  private def context_mark?
    @parser.value.context_mark
  end

  private def context_line_number
    # YAML starts counting from 0, we want to count from 1
    context_mark?.line + 1
  end

  private def context_column_number
    # YAML starts counting from 0, we want to count from 1
    context_mark?.column + 1
  end

  def finalize
    return if @closed

    LibYAML.yaml_parser_delete(@parser)
    LibYAML.yaml_event_delete(pointerof(@event))
  end

  def close
    finalize
    @closed = true
  end

  # Raises if the current kind is not the expected one.
  def expect_kind(kind : EventKind)
    raise "Expected #{kind} but was #{self.kind}" unless kind == self.kind
  end

  private def read_anchor(anchor)
    anchor ? String.new(anchor) : nil
  end

  def raise(msg : String, line_number = self.start_line, column_number = self.start_column, context_info = nil)
    ::raise ParseException.new(msg, line_number, column_number, context_info)
  end
end
