module Crystal
  module DWARF
    class Backtraces
      property debug_abbrev : Bytes?
      property debug_info : Bytes?
      property debug_line : Bytes?
      property debug_line_str : Bytes?
      property debug_str : Bytes?

      # index to each individual abbreviation at an abbrev offset, so we don't have
      # to scan debug_abbrev over and over again to find the abbreviations we're
      # looking for, we can directly pinpoint the abbrev we need
      @abbrev_indexes = Hash(UInt64, Array(Int32)).new

      @initialized = false

      def build_caches : Nil
        build_abbrev_indexes
        @initialized = true
      end

      # Cache individual offsets to each abbreviation into DEBUG_ABBREV for every
      # debug abbrev offset of DEBUG_INFO. Dramatically improves the performance
      # of looking up function names.
      private def build_abbrev_indexes : Nil
        return unless debug_abbrev = @debug_abbrev
        return unless debug_info = @debug_info

        Crystal::DWARF.each_info(debug_info) do |info|
          abbrev_table = debug_abbrev + info.debug_abbrev_offset

          @abbrev_indexes[info.debug_abbrev_offset] ||= Array(Int32).new.tap do |index|
            Crystal::DWARF.each_abbrev(abbrev_table) do |abbrev, offset|
              index << offset
              abbrev.each_attribute { }
            end
          end
        end
      end

      def lookup_function_name(pc : Int) : Bytes?
        return unless @initialized
        return unless debug_abbrev = @debug_abbrev
        return unless debug_info = @debug_info

        DWARF.each_info(debug_info) do |info|
          abbrev_table = debug_abbrev + info.debug_abbrev_offset
          abbrev_index = @abbrev_indexes[info.debug_abbrev_offset]

          info.each do |abbrev_code|
            offset = abbrev_index[abbrev_code &- 1]

            DWARF.abbrev_at(abbrev_table + offset) do |abbrev|
              if abbrev.tag == DW_TAG_subprogram
                low_pc = nil
                high_pc = nil
                name_form = nil
                name_value = nil

                abbrev.each_attribute do |attr|
                  value = info.read_attribute_value(attr.form, attr.const_value)

                  case attr.at
                  when DW_AT_low_pc
                    low_pc = value.as(LibC::SizeT)
                  when DW_AT_high_pc
                    if attr.form == DW_FORM_addr
                      high_pc = value.as(LibC::SizeT)
                    elsif value.responds_to?(:to_u64)
                      high_pc = low_pc.as(LibC::SizeT) + value.to_u64
                    end
                  when DW_AT_name
                    name_form = attr.form
                    name_value = value
                  end
                end

                if low_pc && high_pc && name_form && name_value
                  if low_pc <= pc <= high_pc
                    return decode_str(name_form, name_value)
                  end
                end
              else
                abbrev.each_attribute do |attr|
                  info.skip_attribute_value(attr.form)
                end
              end
            end
          end
        end
      end

      def lookup_line_number(pc : Int) : {Bytes, Bytes, UInt32, UInt32} | Nil
        each_line_number do |sequence, low_pc, limit_pc, file_index, line, column|
          if low_pc <= pc < limit_pc
            directory, file = file_and_directory_at(sequence, file_index)
            return directory, file, line, column
          end
        end
      end

      def each_line_number(&) : Nil
        return unless @initialized
        return unless debug_line = @debug_line

        DWARF.each_line_sequence(debug_line) do |sequence|
          # state of the previous entry in the matrix
          address = 0_u64
          file_index = 0_u32
          line = 0_u32
          column = 0_u32

          registers = Line::Registers.new(sequence.default_is_stmt?)

          sequence.read_statement_program(pointerof(registers)) do
            unless address.zero? || line.zero?
              yield pointerof(sequence), address, registers.address, file_index, line, column
            end

            # save state
            if registers.end_sequence?
              address = 0_u64
            else
              address = registers.address
            end
            file_index = registers.file
            line = registers.line
            column = registers.column
          end
        end
      end

      private def file_and_directory_at(sequence, file_index)
        file = Bytes.empty
        directory = Bytes.empty
        directory_index = 0

        # must parse directories before we can parse files (skip)
        sequence.value.each_directory { }

        # files are 1-indexed
        i = 1
        sequence.value.each_file do |(form, value), dir_index, _, _, _|
          if i == file_index
            file = decode_str(form, value)
            directory_index = dir_index
            break
          end
          i += 1
        end

        unless file.empty?
          case directory_index
          when 0
            # special case
            directory = ".".to_slice
          else
            # re-parse the directories to get the file's directory
            sequence.value.rewind_headers

            # directories are 1-indexed
            i = 1
            sequence.value.each_directory do |(form, value)|
              if i == directory_index
                directory = decode_str(form, value)
                break
              end
              i += 1
            end
          end
        end

        {directory, file}
      end

      private def decode_str(form, value)
        case form
        when DW_FORM_string
          value.as(Bytes)
        when DW_FORM_strp
          decode_strp(@debug_str, value.as(UInt8 | UInt16 | UInt32 | UInt64))
        when DW_FORM_line_strp
          decode_strp(@debug_line_str, value.as(UInt8 | UInt16 | UInt32 | UInt64))
        else
          Bytes.empty
        end
      end

      private def decode_strp(bytes, offset)
        if bytes && (0 <= offset < bytes.size)
          pointer = bytes.to_unsafe + offset
          bytesize = LibC.strlen(pointer).to_i32
          Bytes.new(pointer, bytesize, read_only: true)
        else
          Bytes.empty
        end
      end
    end
  end
end
