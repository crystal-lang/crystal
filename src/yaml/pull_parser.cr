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
    parse_exception "Expected STREAM_START" unless kind == LibYAML::EventType::STREAM_START
  end

  def self.new(content)
    parser = new(content)
    yield parser ensure parser.close
  end

  def kind
    @event.type
  end

  def tag
    ptr = @event.data.scalar.tag
    ptr ? String.new(ptr) : nil
  end

  def value
    ptr = @event.data.scalar.value
    ptr ? String.new(ptr) : nil
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

  def read_stream
    read_stream_start
    value = yield
    read_stream_end
    value
  end

  def read_document
    read_document_start
    value = yield
    read_document_end
    value
  end

  def read_sequence
    read_sequence_start
    value = yield
    read_sequence_end
    value
  end

  def read_mapping
    read_mapping_start
    value = yield
    read_mapping_end
    value
  end

  def read_alias
    expect_kind EventKind::ALIAS
    anchor = alias_anchor
    read_next
    anchor
  end

  def read_scalar
    expect_kind EventKind::SCALAR
    value = self.value.not_nil!
    read_next
    value
  end

  def read_stream_start
    read EventKind::STREAM_START
  end

  def read_stream_end
    read EventKind::STREAM_END
  end

  def read_document_start
    read EventKind::DOCUMENT_START
  end

  def read_document_end
    read EventKind::DOCUMENT_END
  end

  def read_sequence_start
    read EventKind::SEQUENCE_START
  end

  def read_sequence_end
    read EventKind::SEQUENCE_END
  end

  def read_mapping_start
    read EventKind::MAPPING_START
  end

  def read_mapping_end
    read EventKind::MAPPING_END
  end

  def read_null_or
    if kind == EventKind::SCALAR && (value = self.value).nil? || (value && value.empty?)
      read_next
      nil
    else
      yield
    end
  end

  def read(expected_kind)
    expect_kind expected_kind
    read_next
  end

  def read_raw
    case kind
    when EventKind::SCALAR
      self.value.not_nil!.tap { read_next }
    when EventKind::SEQUENCE_START, EventKind::MAPPING_START
      String.build { |io| read_raw(io) }
    else
      parse_exception "unexpected kind: #{kind}"
    end
  end

  def read_raw(io)
    case kind
    when EventKind::SCALAR
      self.value.not_nil!.inspect(io)
      read_next
    when EventKind::SEQUENCE_START
      io << "["
      read_next
      first = true
      while kind != EventKind::SEQUENCE_END
        io << "," unless first
        read_raw(io)
        first = false
      end
      io << "]"
      read_next
    when EventKind::MAPPING_START
      io << "{"
      read_next
      first = true
      while kind != EventKind::MAPPING_END
        io << "," unless first
        read_raw(io)
        io << ":"
        read_raw(io)
        first = false
      end
      io << "}"
      read_next
    else
      parse_exception "unexpected kind: #{kind}"
    end
  end

  def skip
    case kind
    when EventKind::SCALAR
      read_next
    when EventKind::ALIAS
      read_next
    when EventKind::SEQUENCE_START
      read_next
      while kind != EventKind::SEQUENCE_END
        skip
      end
      read_next
    when EventKind::MAPPING_START
      read_next
      while kind != EventKind::MAPPING_END
        skip
        skip
      end
      read_next
    end
  end

  def line_number
    @event.start_mark.line
  end

  def column_number
    @event.start_mark.column
  end

  def problem_line_number
    problem? ? problem_mark.line : line_number
  end

  def problem_column_number
    problem? ? problem_mark.column : column_number
  end

  def problem_mark
    @parser.value.problem_mark
  end

  private def problem?
    @parser.value.problem
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

  private def expect_kind(kind)
    parse_exception "expected #{kind} but was #{self.kind}" unless kind == self.kind
  end

  private def read_anchor(anchor)
    anchor ? String.new(anchor) : nil
  end

  private def parse_exception(msg)
    raise ParseException.new(msg, problem_line_number, problem_column_number)
  end
end
