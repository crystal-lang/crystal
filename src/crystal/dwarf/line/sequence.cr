module Crystal::DWARF
  module Line
    struct Sequence
      property minimum_instruction_length : UInt8
      property maximum_operations_per_instruction : UInt8
      property line_base : Int8
      property line_range : UInt8
      property opcode_base : UInt8
      property standard_opcode_lengths : Slice(UInt8)
      property? default_is_stmt : Bool
      @version : UInt8
      @dwarf64 : Bool

      def initialize(@dwarf64, @version, headers : Bytes, @program : Bytes,
                     @minimum_instruction_length, @maximum_operations_per_instruction,
                     @default_is_stmt, @line_base, @line_range, @opcode_base,
                     @standard_opcode_lengths)
        @headers = Reader.new(headers)
      end

      # Rewinds the headers' reader so we can restart parsing directories, then
      # files.
      def rewind_headers : Nil
        @headers.rewind
      end

      # Iterates the directory paths for the sequence. Can be iterated
      # independently from the statement program.
      #
      # WARNING: May only be called once.
      # WARNING: Must be called before `#each_file`.
      def each_directory(&) : Nil
        if @version >= 5
          each_lnct { |path| yield path }
        else
          each_directory_v2 { |path| yield path }
        end
      end

      # Iterates the file names for the sequence. Can be iterated independently
      # from the statement program.
      #
      # WARNING: May only be called once.
      # WARNING: Must be called after `#each_directory`.
      def each_file(&) : Nil
        if @version >= 5
          each_lnct { |*args| yield *args }
        else
          each_file_v2 { |*args| yield *args }
        end
      end

      # Resolves the program. Yields every time *registers* shall be appended to
      # the matrix.
      #
      # TODO: DW_LNE_define_file (uncommon, deprecated in DWARF 5)
      def read_statement_program(registers : Registers*, &)
        reader = Reader.new(@program)

        until reader.eof?
          opcode = reader.read_u8

          if opcode >= @opcode_base
            # special opcode
            adjusted_opcode = opcode &- @opcode_base
            increment_address_and_op_index(registers, adjusted_opcode // @line_range)
            registers.value.line = registers.value.line &+ @line_base &+ (adjusted_opcode % @line_range)
            yield
            registers.value.reset
          elsif opcode == 0
            # extended opcode
            len = reader.read_uleb128 &- 1 # -1 accounts for the opcode

            case reader.read_u8
            when DW_LNE_end_sequence
              registers.value.end_sequence = true
              yield
              break if reader.eof?
              registers.value = Registers.new(@default_is_stmt)
            when DW_LNE_set_address
              case len
              when 8 then registers.value.address = reader.read_u64
              when 4 then registers.value.address = reader.read_u32.to_u64
              else        reader.skip(len)
              end
              registers.value.op_index = 0_u32
            when DW_LNE_set_discriminator
              registers.value.discriminator = reader.read_uleb128
            else
              # unsupported
              reader.skip(len)
            end
          else
            # standard opcode
            case opcode
            when DW_LNS_copy
              yield
              registers.value.reset
            when DW_LNS_advance_pc
              operation_advance = reader.read_uleb128
              increment_address_and_op_index(registers, operation_advance)
            when DW_LNS_advance_line
              registers.value.line = registers.value.line &+ reader.read_sleb128
            when DW_LNS_set_file
              registers.value.file = reader.read_uleb128
            when DW_LNS_set_column
              registers.value.column = reader.read_uleb128
            when DW_LNS_negate_stmt
              registers.value.is_stmt = !registers.value.is_stmt?
            when DW_LNS_set_basic_block
              registers.value.basic_block = true
            when DW_LNS_const_add_pc
              adjusted_opcode = 255 &- @opcode_base
              operation_advance = adjusted_opcode // @line_range
              increment_address_and_op_index(registers, operation_advance)
            when DW_LNS_fixed_advance_pc
              registers.value.address = registers.value.address &+ reader.read_u16
              registers.value.op_index = 0_u32
            when DW_LNS_set_prologue_end
              registers.value.prologue_end = true
            when DW_LNS_set_epilogue_begin
              registers.value.epilogue_begin = true
            when DW_LNS_set_isa
              registers.value.isa = reader.read_uleb128
            else
              # unsupported, consume unknown args
              n_args = @standard_opcode_lengths[opcode &- 1]
              n_args.times { reader.read_uleb128 }
            end
          end
        end
      end

      private def increment_address_and_op_index(registers, operation_advance)
        if @maximum_operations_per_instruction == 1
          registers.value.address = registers.value.address &+ operation_advance &* @minimum_instruction_length
        else
          registers.value.address = registers.value.address &+ @minimum_instruction_length.to_u64 &* ((registers.value.op_index &+ operation_advance) // @maximum_operations_per_instruction)
          registers.value.op_index = (registers.value.op_index &+ operation_advance) % @maximum_operations_per_instruction
        end
      end

      private def each_directory_v2(&)
        until (dirname = @headers.read_string).size == 0
          path = {DW_FORM_string, dirname}
          yield path
        end
      end

      private def each_file_v2(&)
        until (filename = @headers.read_string).size == 0
          path = {DW_FORM_string, filename}
          directory_index = @headers.read_uleb128
          timestamp = @headers.read_uleb128.to_u64
          size = @headers.read_uleb128.to_u64
          yield path, directory_index, timestamp, size, nil
        end
      end

      private def each_lnct(&)
        buf = uninitialized Tuple(UInt32, UInt32)[255]

        formats = buf.to_slice[0, @headers.read_u8].fill do
          {
            @headers.read_uleb128, # DW_LNCT
            @headers.read_uleb128, # DW_FORM
          }
        end

        @headers.read_u8.times do |i|
          path = nil
          directory_index = 0_u32
          timestamp = 0_u64
          size = 0_u64
          md5 = Bytes.empty

          formats.each do |(lnct, form)|
            case lnct
            when DW_LNCT_path
              path = {form, lnct_path_value(form)}
            when DW_LNCT_directory_index
              directory_index = lnct_directory_index_value(form)
            when DW_LNCT_timestamp
              timestamp = lnct_timestamp_value(form)
            when DW_LNCT_size
              size = lnct_size_value(form)
            when DW_LNCT_md5
              md5 = lnct_md5_value(form)
            else
              lnct_skip(form)
            end
          end

          yield path, directory_index, timestamp, size, md5 if path
        end
      end

      private def lnct_path_value(form)
        case form
        when DW_FORM_string
          @headers.read_string
        when DW_FORM_line_strp
          @headers.read_ulong(@dwarf64 ? 8 : 4)
        when DW_FORM_strp
          @headers.read_ulong(@dwarf64 ? 8 : 4)
        when DW_FORM_strp_sup, DW_FORM_strx
          @headers.read_uleb128
        when DW_FORM_strx1
          @headers.read_u8
        when DW_FORM_strx2
          @headers.read_u16
        when DW_FORM_strx3
          @headers.read_u24
        when DW_FORM_strx4
          @headers.read_u32
        else
          raise Error.new("Unexpected FORM value=#{form}")
        end
      end

      private def lnct_directory_index_value(form)
        case form
        when DW_FORM_data1
          @headers.read_u8
        when DW_FORM_data2
          @headers.read_u16
        when DW_FORM_udata
          @headers.read_uleb128
        else
          raise Error.new("Unexpected FORM value=#{form}")
        end
      end

      private def lnct_timestamp_value(form)
        case form
        when DW_FORM_data4
          @headers.read_u32
        when DW_FORM_data8
          @headers.read_u64
        when DW_FORM_udata
          @headers.read_uleb128
        when DW_FORM_block
          @headers.read_uleb128
        else
          raise Error.new("Unexpected FORM value=#{form}")
        end
      end

      private def lnct_size_value(form)
        case form
        when DW_FORM_data1
          @headers.read_u8
        when DW_FORM_data2
          @headers.read_u16
        when DW_FORM_data4
          @headers.read_u32
        when DW_FORM_data8
          @headers.read_u64
        when DW_FORM_udata, DW_FORM_block
          @headers.read_uleb128
        else
          raise Error.new("Unexpected FORM value=#{form}")
        end
      end

      private def lnct_md5_value(form)
        case form
        when DW_FORM_data16
          @headers.read(16)
        else
          raise Error.new("Unexpected FORM value=#{form}")
        end
      end

      private def lnct_skip(form)
        case form
        when DW_FORM_block, DW_FORM_strx, DW_FORM_udata
          @headers.read_uleb128
        when DW_FORM_block1, DW_FORM_data1, DW_FORM_strx1, DW_FORM_flag
          @headers.skip(1)
        when DW_FORM_block2, DW_FORM_data2, DW_FORM_strx2
          @headers.skip(2)
        when DW_FORM_block4, DW_FORM_data4, DW_FORM_strx4
          @headers.skip(4)
        when DW_FORM_data8
          @headers.skip(8)
        when DW_FORM_data16
          @headers.skip(16)
        when DW_FORM_line_strp, DW_FORM_strp, DW_FORM_sec_offset
          @headers.skip(@dwarf64 ? 8 : 4)
        when DW_FORM_sdata
          @headers.read_sleb128
        when DW_FORM_string
          @headers.skip_string
        when DW_FORM_strx3
          @headers.skip(3)
        else
          raise Error.new("Unexpected FORM value=#{form}")
        end
      end
    end
  end
end
