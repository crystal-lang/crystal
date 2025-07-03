require "crystal/dwarf"
{% if flag?(:darwin) %}
  require "./mach_o"
{% else %}
  require "./elf"
{% end %}

struct Exception::CallStack
  @@dwarf_loaded = false
  @@dwarf_line_numbers : Crystal::DWARF::LineNumbers?
  @@dwarf_function_names : Array(Tuple(LibC::SizeT, LibC::SizeT, String))?

  {% if flag?(:win32) %}
    @@coff_symbols : Hash(Int32, Array(Crystal::PE::COFFSymbol))?
  {% end %}

  # :nodoc:
  def self.load_debug_info : Nil
    return if ENV["CRYSTAL_LOAD_DEBUG_INFO"]? == "0"

    unless @@dwarf_loaded
      @@dwarf_loaded = true
      begin
        load_debug_info_impl
      rescue ex
        @@dwarf_line_numbers = nil
        @@dwarf_function_names = nil
        Crystal::System.print_exception "Unable to load dwarf information", ex
      end
    end
  end

  protected def self.decode_line_number(pc)
    load_debug_info
    if ln = @@dwarf_line_numbers
      if row = ln.find(pc)
        return {row.path, row.line, row.column}
      end
    end
    {"??", 0, 0}
  end

  protected def self.decode_function_name(pc)
    load_debug_info
    if fn = @@dwarf_function_names
      fn.each do |(low_pc, high_pc, function_name)|
        return function_name if low_pc <= pc <= high_pc
      end
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
