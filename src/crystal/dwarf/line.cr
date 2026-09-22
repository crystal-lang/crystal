module Crystal::DWARF
  def self.each_line_sequence(bytes : Bytes, & : Line::Sequence, Int32 ->) : Nil
    reader = Reader.new(bytes)

    until reader.eof?
      offset = reader.pos

      line_sequence_at_impl(pointerof(reader)) do |sequence|
        yield sequence, offset
      end
    end
  end

  def self.line_sequence_at(bytes : Bytes, & : Line::Sequence ->) : Nil
    reader = Reader.new(bytes)

    line_sequence_at_impl(pointerof(reader)) do |sequence|
      yield sequence
    end
  end

  private def self.line_sequence_at_impl(reader, &) : Nil
    unit_length = reader.value.read_u32
    dwarf64 = unit_length == 0xffffffff
    unit_length = reader.value.read_u64 if dwarf64
    offset = reader.value.pos
    version = reader.value.read_u16

    if version >= 5
      _address_size = reader.value.read_u8
      _segment_selector_size = reader.value.read_u8
    elsif version >= 2
      # _address_size = {% if flag?(:bits64) %} 8_u8 {% else %} 4_u8 {% end %}
      # _segment_selector_size = 0_u8
    else
      raise Error.new("Unsupported version #{version}")
    end

    header_length = reader.value.read_ulong(dwarf64 ? 8 : 4)
    header_offset = reader.value.pos

    minimum_instruction_length = reader.value.read_u8
    maximum_operations_per_instruction = version >= 4 ? reader.value.read_u8 : 1_u8
    default_is_stmt = reader.value.read_u8 == 1
    line_base = reader.value.read_i8
    line_range = reader.value.read_u8
    opcode_base = reader.value.read_u8
    standard_opcode_lengths = reader.value.read(opcode_base - 1)

    # directories / filenames, then statement program
    headers = reader.value.read(header_length - (reader.value.pos - header_offset))
    program = reader.value.read(unit_length - (reader.value.pos - offset))

    yield Line::Sequence.new(dwarf64, version.to_u8, headers, program,
      minimum_instruction_length, maximum_operations_per_instruction,
      default_is_stmt, line_base, line_range, opcode_base,
      standard_opcode_lengths)
  end
end
