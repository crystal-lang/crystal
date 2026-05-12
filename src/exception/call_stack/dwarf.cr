require "crystal/dwarf"

struct Exception::CallStack
  @@dwarf_line_numbers : Crystal::DWARF::LineNumbers?
  @@dwarf_function_names : Array(Tuple(LibC::SizeT, LibC::SizeT, String))?

  protected def self.decode_line_number(pc)
    if ln = @@dwarf_line_numbers
      if row = ln.find(pc)
        return {row.path, row.line, row.column}
      end
    end
    {"??", 0, 0}
  end

  protected def self.decode_function_name(pc)
    if fn = @@dwarf_function_names
      fn.each do |(low_pc, high_pc, function_name)|
        return function_name if low_pc <= pc <= high_pc
      end
    end
  end

  protected def self.read_dwarf_sections(image, base_address = 0_u64) : Nil
    line_strings = image.read_section?(DEBUG_LINE_STR) do |sh, io|
      Crystal::DWARF::Strings.new(io, sh.offset, sh.size)
    end

    strings = image.read_section?(DEBUG_STR) do |sh, io|
      Crystal::DWARF::Strings.new(io, sh.offset, sh.size)
    end

    image.read_section?(DEBUG_LINE) do |sh, io|
      @@dwarf_line_numbers = Crystal::DWARF::LineNumbers.new(io, sh.size, base_address, strings, line_strings)
    end

    abbrevs_tables = image.read_section?(DEBUG_ABBREV) do |sh, io|
      all = {} of Int64 => Array(Crystal::DWARF::Abbrev)
      while (offset = io.pos - sh.offset) < sh.size
        all[offset] = Crystal::DWARF::Abbrev.read(io)
      end
      all
    end

    image.read_section?(DEBUG_INFO) do |sh, io|
      names = [] of {LibC::SizeT, LibC::SizeT, String}

      while (offset = io.pos - sh.offset) < sh.size
        info = Crystal::DWARF::Info.new(io, offset)

        if abbrevs_tables
          if abbreviations = abbrevs_tables[info.debug_abbrev_offset]?
            info.abbreviations = abbreviations
          end
        end

        parse_function_names_from_dwarf(info, strings, line_strings) do |low_pc, high_pc, name|
          names << {low_pc + base_address, high_pc + base_address, name}
        end
      end

      @@dwarf_function_names = names
    end
  end

  protected def self.parse_function_names_from_dwarf(info, strings, line_strings, &)
    info.each do |code, abbrev, attributes|
      next unless abbrev && abbrev.tag.subprogram?
      name = low_pc = high_pc = nil

      attributes.each do |(at, form, value)|
        case at
        when Crystal::DWARF::AT::DW_AT_name
          value = strings.try(&.decode(value.as(UInt32 | UInt64))) if form.strp?
          value = line_strings.try(&.decode(value.as(UInt32 | UInt64))) if form.line_strp?
          name = value.as(String)
        when Crystal::DWARF::AT::DW_AT_low_pc
          low_pc = value.as(LibC::SizeT)
        when Crystal::DWARF::AT::DW_AT_high_pc
          if form.addr?
            high_pc = value.as(LibC::SizeT)
          elsif value.responds_to?(:to_i)
            high_pc = low_pc.as(LibC::SizeT) + value.to_i
          end
        else
          # Not an attribute we care
        end
      end

      if low_pc && high_pc && name
        yield low_pc, high_pc, name
      end
    end
  end
end
