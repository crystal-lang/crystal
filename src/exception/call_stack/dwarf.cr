require "crystal/dwarf"

struct Exception::CallStack
  @@dwarf = Crystal::DWARF::Backtraces.new

  protected def self.preload_dwarf_sections(program) : Nil
    program.section?(DEBUG_ABBREV) { |bytes, _| @@dwarf.debug_abbrev = bytes }
    program.section?(DEBUG_INFO) { |bytes, _| @@dwarf.debug_info = bytes }
    program.section?(DEBUG_LINE) { |bytes, _| @@dwarf.debug_line = bytes }
    program.section?(DEBUG_LINE_STR) { |bytes, _| @@dwarf.debug_line_str = bytes }
    program.section?(DEBUG_STR) { |bytes, _| @@dwarf.debug_str = bytes }
    @@dwarf.build_caches
  end

  # OPTIMIZE: return bytes instead of allocating a string
  protected def self.decode_line_number(pc)
    if result = @@dwarf.lookup_line_number(pc)
      directory, file, line, column = result
      unless directory.empty? && file.empty?
        path =
          if directory.empty?
            String.new(file)
          else
            bytesize = directory.size + File::SEPARATOR_STRING.size + file.size
            String.build(bytesize) do |io|
              io.write(directory)
              io << File::SEPARATOR_STRING
              io.write(file)
            end
          end
        return {path, line.to_i32, column.to_i32}
      end
    end
    {"??", 0, 0}
  end

  # OPTIMIZE: return bytes instead of allocating a string
  protected def self.decode_function_name(pc)
    if bytes = @@dwarf.lookup_function_name(pc)
      String.new(bytes)
    end
  end
end
