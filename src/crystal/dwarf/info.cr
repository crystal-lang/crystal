require "../dwarf"
require "./abbrev"

module Crystal
  module DWARF
    struct Info
      property unit_length : UInt32 | UInt64
      property version : UInt16
      property unit_type : UInt8
      property debug_abbrev_offset : UInt32 | UInt64
      property address_size : UInt8
      property! abbreviations : Array(Abbrev)

      property dwarf64 : Bool
      @offset : Int64
      @ref_offset : Int64

      def initialize(@io : IO::Memory, @ref_offset)
        @unit_length = @io.read_bytes(UInt32)
        if @unit_length == 0xffffffff
          @dwarf64 = true
          @unit_length = @io.read_bytes(UInt64)
        else
          @dwarf64 = false
        end

        @offset = @io.tell.to_i64
        @version = @io.read_bytes(UInt16)

        if @version < 2 || @version > 5
          raise "Unsupported DWARF version #{@version}"
        end

        if @version >= 5
          @unit_type = @io.read_bytes(UInt8)
          @address_size = @io.read_bytes(UInt8)
          @debug_abbrev_offset = read_ulong
        else
          @unit_type = 0
          @debug_abbrev_offset = read_ulong
          @address_size = @io.read_bytes(UInt8)
        end

        if @address_size.zero?
          raise "Invalid address size: 0"
        end
      end

      alias Value = Bool | Int32 | Int64 | Slice(UInt8) | String | UInt16 | UInt32 | UInt64 | UInt8 | UInt128

      # The offset right past the last byte of this compilation unit within
      # the section.
      def unit_end : Int64
        @offset + @unit_length.to_i64!
      end

      # Iterates the subprogram entries of the compilation unit without
      # materializing any attribute value on the heap: values are skipped,
      # except for the pc range and the raw form and value of the name
      # attribute, which are read as plain integers.
      #
      # Yields the subprogram's low pc, high pc, name form and name value.
      # The name can then be decoded — only for subprograms whose pc range is
      # of interest — via `Strings#decode` (`DW_FORM_strp`/`DW_FORM_line_strp`,
      # the value is an offset) or `#string_at` (`DW_FORM_string`, the value
      # is a position within this section).
      #
      # Subprograms missing any of these attributes, or using forms that
      # cannot be decoded without further DWARF 5 sections (`DW_FORM_strx*`,
      # `DW_FORM_addrx*`), are skipped.
      def each_subprogram(& : UInt64, UInt64, FORM, UInt64 ->) : Nil
        end_offset = unit_end
        abbreviations = @abbreviations
        return unless abbreviations

        while @io.pos < end_offset
          code = DWARF.read_unsigned_leb128(@io)
          next if code == 0 # null entry: end of a list of children

          # we cannot skip over an entry of unknown layout, so stop here
          abbrev = abbreviations[code &- 1]? || return

          unless abbrev.tag.subprogram?
            abbrev.attributes.each do |attr|
              skip_attribute_value(attr.form)
            end
            next
          end

          name_form = nil
          name_value = 0_u64
          low_pc = nil
          high_pc = nil
          high_pc_is_offset = false

          abbrev.attributes.each do |attr|
            case attr.at
            when .dw_at_name?
              case attr.form
              when .strp?, .line_strp?
                name_form = attr.form
                name_value = read_ulong.to_u64!
              when .string?
                name_form = attr.form
                name_value = @io.pos.to_u64
                skip_string
              else
                skip_attribute_value(attr.form)
              end
            when .dw_at_low_pc?
              if attr.form.addr?
                low_pc = read_address
              else
                skip_attribute_value(attr.form)
              end
            when .dw_at_high_pc?
              case attr.form
              when .addr?
                high_pc = read_address
              when .data1?, .data2?, .data4?, .data8?, .udata?
                high_pc = read_unsigned_data(attr.form)
                high_pc_is_offset = true
              when .implicit_const?
                high_pc = attr.value.to_u64!
                high_pc_is_offset = true
              else
                skip_attribute_value(attr.form)
              end
            else
              skip_attribute_value(attr.form)
            end
          end

          if (form = name_form) && (low = low_pc) && (high = high_pc)
            high = low &+ high if high_pc_is_offset
            yield low, high, form, name_value
          end
        end
      end

      # Reads the null-terminated string at the given position within the
      # section, preserving the current position.
      def string_at(pos : UInt64) : String?
        old_pos = @io.pos
        begin
          @io.pos = pos
          @io.gets('\0', chomp: true)
        ensure
          @io.pos = old_pos
        end
      end

      private def read_address : UInt64
        case address_size
        when 4 then @io.read_bytes(UInt32).to_u64
        when 8 then @io.read_bytes(UInt64)
        else        raise "Invalid address size: #{address_size}"
        end
      end

      private def read_unsigned_data(form : FORM) : UInt64
        case form
        when .data1? then @io.read_byte.not_nil!.to_u64
        when .data2? then @io.read_bytes(UInt16).to_u64
        when .data4? then @io.read_bytes(UInt32).to_u64
        when .data8? then @io.read_bytes(UInt64)
        else              DWARF.read_unsigned_leb128(@io).to_u64
        end
      end

      # Skips over an attribute value without materializing it. Unlike
      # `#read_attribute_value` this tolerates every DWARF 5 form: the
      # values only need their size to be known.
      private def skip_attribute_value(form : FORM) : Nil
        case form
        when .addr?
          @io.skip(address_size)
        when .block1?
          @io.skip(@io.read_byte.not_nil!.to_i)
        when .block2?
          @io.skip(@io.read_bytes(UInt16).to_i)
        when .block4?
          @io.skip(@io.read_bytes(UInt32).to_i64)
        when .block?, .exprloc?
          @io.skip(DWARF.read_unsigned_leb128(@io))
        when .data1?, .ref1?, .flag?, .strx1?, .addrx1?
          @io.skip(1)
        when .data2?, .ref2?, .strx2?, .addrx2?
          @io.skip(2)
        when .strx3?, .addrx3?
          @io.skip(3)
        when .data4?, .ref4?, .refsup4?, .strx4?, .addrx4?
          @io.skip(4)
        when .data8?, .ref8?, .refsup8?, .ref_sig8?
          @io.skip(8)
        when .data16?
          @io.skip(16)
        when .sdata?
          DWARF.read_signed_leb128(@io)
        when .udata?, .ref_udata?, .strx?, .addrx?, .loclistx?, .rnglistx?
          DWARF.read_unsigned_leb128(@io)
        when .strp?, .line_strp?, .sec_offset?, .ref_addr?, .strp_sup?, .gnustrp_alt?, .gnurefalt?
          @io.skip(@dwarf64 ? 8 : 4)
        when .string?
          skip_string
        when .flag_present?, .implicit_const?
          # no data
        when .indirect?
          skip_attribute_value(FORM.new(DWARF.read_unsigned_leb128(@io)))
        else
          raise "Unknown DW_FORM_#{form.to_s.underscore}"
        end
      end

      private def skip_string : Nil
        slice = @io.to_slice
        if index = slice.index(0_u8, @io.pos)
          @io.pos = index + 1
        else
          @io.pos = slice.size
        end
      end

      def each(&)
        end_offset = @offset + @unit_length
        attributes = [] of {AT, FORM, Value}

        while @io.tell < end_offset
          code = DWARF.read_unsigned_leb128(@io)
          attributes.clear

          if abbrev = @abbreviations.try &.[code &- 1]? # @abbreviations.try &.find { |a| a.code == abbrev }
            abbrev.attributes.each do |attr|
              value = read_attribute_value(attr.form, attr)
              attributes << {attr.at, attr.form, value}
            end
            yield code, abbrev, attributes
          else
            yield code, nil, attributes
          end
        end
      end

      private def read_attribute_value(form, attr)
        case form
        when FORM::Addr
          case address_size
          when 4 then @io.read_bytes(UInt32)
          when 8 then @io.read_bytes(UInt64)
          else        raise "Invalid address size: #{address_size}"
          end
        when FORM::Block1
          len = @io.read_byte.not_nil!
          @io.read_fully(bytes = Bytes.new(len.to_i))
          bytes
        when FORM::Block2
          len = @io.read_bytes(UInt16)
          @io.read_fully(bytes = Bytes.new(len.to_i))
          bytes
        when FORM::Block4
          len = @io.read_bytes(UInt32)
          @io.read_fully(bytes = Bytes.new(len.to_i64))
          bytes
        when FORM::Block
          len = DWARF.read_unsigned_leb128(@io)
          @io.read_fully(bytes = Bytes.new(len))
          bytes
        when FORM::Data1
          @io.read_byte.not_nil!
        when FORM::Data2
          @io.read_bytes(UInt16)
        when FORM::Data4
          @io.read_bytes(UInt32)
        when FORM::Data8
          @io.read_bytes(UInt64)
        when FORM::Data16
          @io.read_bytes(UInt128)
        when FORM::Sdata
          DWARF.read_signed_leb128(@io)
        when FORM::Udata
          DWARF.read_unsigned_leb128(@io)
        when FORM::ImplicitConst
          attr.value
        when FORM::Exprloc
          len = DWARF.read_unsigned_leb128(@io)
          @io.read_fully(bytes = Bytes.new(len))
          bytes
        when FORM::Flag
          @io.read_byte == 1
        when FORM::FlagPresent
          true
        when FORM::SecOffset
          read_ulong
        when FORM::Ref1
          @ref_offset + @io.read_byte.not_nil!.to_u64
        when FORM::Ref2
          @ref_offset + @io.read_bytes(UInt16).to_u64
        when FORM::Ref4
          @ref_offset + @io.read_bytes(UInt32).to_u64
        when FORM::Ref8
          @ref_offset + @io.read_bytes(UInt64).to_u64
        when FORM::RefUdata
          @ref_offset + DWARF.read_unsigned_leb128(@io)
        when FORM::RefAddr
          read_ulong
        when FORM::RefSig8
          @io.read_bytes(UInt64)
        when FORM::String
          @io.gets('\0', chomp: true).to_s
        when FORM::Strp, FORM::LineStrp
          # HACK: A call to read_ulong is failing with an .ud2 / Illegal instruction: 4 error
          #       Calling with @[AlwaysInline] makes no difference.
          if @dwarf64
            @io.read_bytes(UInt64)
          else
            @io.read_bytes(UInt32)
          end
        when FORM::Indirect
          form = FORM.new(DWARF.read_unsigned_leb128(@io))
          read_attribute_value(form, attr)
        else
          raise "Unknown DW_FORM_#{form.to_s.underscore}"
        end
      end

      private def read_ulong
        if @dwarf64
          @io.read_bytes(UInt64)
        else
          @io.read_bytes(UInt32)
        end
      end
    end
  end
end
