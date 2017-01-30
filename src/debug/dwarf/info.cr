require "../dwarf"
require "./abbrev"

module Debug
  module DWARF
    struct Info
      property unit_length : UInt32 | UInt64
      property version : UInt16
      property debug_abbrev_offset : UInt32 | UInt64
      property address_size : UInt8
      property! abbreviations : Array(Abbrev)

      property dwarf64 : Bool
      @offset : LibC::OffT
      @ref_offset : LibC::OffT

      def initialize(@io : IO::FileDescriptor, @offset)
        @ref_offset = offset

        @unit_length = @io.read_bytes(UInt32)
        if @unit_length == 0xffffffff
          @dwarf64 = true
          @unit_length = @io.read_bytes(UInt64)
        else
          @dwarf64 = false
        end

        @offset = @io.tell
        @version = @io.read_bytes(UInt16)
        @debug_abbrev_offset = read_ulong
        @address_size = @io.read_byte.not_nil!
      end

      alias Value = Bool | Int32 | Int64 | Slice(UInt8) | String | UInt16 | UInt32 | UInt64 | UInt8

      def read_abbreviations(io)
        @abbreviations = Abbrev.read(io, debug_abbrev_offset)
      end

      def each
        end_offset = @offset + @unit_length
        attributes = [] of {AT, FORM, Value}

        while @io.tell < end_offset
          code = DWARF.read_unsigned_leb128(@io)
          attributes.clear

          if abbrev = abbreviations[code - 1]? # abbreviations.find { |a| a.code == abbrev }
            abbrev.attributes.each do |attr|
              value = read_attribute_value(attr.form)
              attributes << {attr.at, attr.form, value}
            end
            yield code, abbrev, attributes
          else
            yield code, nil, attributes
          end
        end
      end

      private def read_attribute_value(form)
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
        when FORM::Sdata
          DWARF.read_signed_leb128(@io)
        when FORM::Udata
          DWARF.read_unsigned_leb128(@io)
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
          @io.gets('\0').to_s.chomp('\0')
        when FORM::Strp
          read_ulong
        when FORM::Indirect
          form = FORM.new(DWARF.read_unsigned_leb128(@io))
          read_attribute_value(form)
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
