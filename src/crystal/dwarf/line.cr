module Crystal::DWARF
  def self.each_line_sequence(bytes : Bytes, & : Line::Sequence ->) : Nil
    reader = Reader.new(bytes)

    until reader.eof?
      unit_length = reader.read_u32
      dwarf64 = unit_length == 0xffffffff
      unit_length = reader.read_u64 if dwarf64
      offset = reader.pos
      version = reader.read_u16

      if version >= 5
        _address_size = reader.read_u8
        _segment_selector_size = reader.read_u8
      elsif version >= 2
        # _address_size = {% if flag?(:bits64) %} 8_u8 {% else %} 4_u8 {% end %}
        # _segment_selector_size = 0_u8
      else
        raise Error.new("Unsupported version #{version}")
      end

      header_length = reader.read_ulong(dwarf64 ? 8 : 4)
      header_offset = reader.pos

      minimum_instruction_length = reader.read_u8
      maximum_operations_per_instruction = version >= 4 ? reader.read_u8 : 1_u8
      default_is_stmt = reader.read_u8 == 1
      line_base = reader.read_i8
      line_range = reader.read_u8
      opcode_base = reader.read_u8
      standard_opcode_lengths = reader.read(opcode_base - 1)

      # directories / filenames, then statement program
      headers = reader.read(header_length - (reader.pos - header_offset))
      program = reader.read(unit_length - (reader.pos - offset))

      yield Line::Sequence.new(dwarf64, version.to_u8, headers, program,
        minimum_instruction_length, maximum_operations_per_instruction,
        default_is_stmt, line_base, line_range, opcode_base,
        standard_opcode_lengths)
    end
  end
end
