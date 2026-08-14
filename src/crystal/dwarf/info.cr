module Crystal::DWARF
  struct Info
    alias Value = Bool | UInt8 | UInt16 | Int32 | UInt32 | UInt64 | UInt128 | Slice(UInt8)

    getter debug_abbrev_offset : UInt64
    getter address_size : UInt8
    getter? dwarf64 : Bool
    getter version : UInt8
    getter unit_type : UInt8
    getter dwo_id : UInt64
    getter type_signature : UInt64
    getter type_offset : UInt64

    def initialize(@dwarf64, @address_size, @debug_abbrev_offset, bytes,
                   version, @unit_type, @dwo_id, @type_signature, @type_offset)
      @version = version.to_u8
      @reader = Reader.new(bytes)
    end

    # Iterates every abbrev code. Skips zero abbrev codes (empty). The caller
    # can safely break the loop to abort parsing the debug info entry.
    #
    # WARNING: The caller must search the associated abbrev and iterate every
    # attribute value in the debug info entry as per the abbrev attributes in
    # order to advance the reader.
    def each(&) : Nil
      until @reader.eof?
        abbrev_code = @reader.read_uleb128
        yield abbrev_code unless abbrev_code == 0
      end
    end

    # Reads the current attribute's value as per the associated `Abbrev` FORM.
    def read_attribute_value(form : UInt32, implicit_const_value : Int32) : Value
      case form
      when DW_FORM_addr
        address_size == 4 ? @reader.read_u32 : @reader.read_u64
      when DW_FORM_addrx, DW_FORM_ref_udata, DW_FORM_rnglistx, DW_FORM_strx, DW_FORM_udata
        @reader.read_uleb128
      when DW_FORM_addrx1, DW_FORM_data1, DW_FORM_ref1, DW_FORM_strx1
        @reader.read_u8
      when DW_FORM_addrx2, DW_FORM_data2, DW_FORM_ref2, DW_FORM_strx2
        @reader.read_u16
      when DW_FORM_addrx3, DW_FORM_strx3
        @reader.read_u24
      when DW_FORM_addrx4, DW_FORM_data4, DW_FORM_ref4, DW_FORM_strx4, DW_FORM_ref_sup4
        @reader.read_u32
      when DW_FORM_block, DW_FORM_exprloc
        @reader.read @reader.read_uleb128
      when DW_FORM_block2
        @reader.read @reader.read_u16
      when DW_FORM_block4
        @reader.read @reader.read_u32
      when DW_FORM_data8, DW_FORM_ref8, DW_FORM_ref_sig8, DW_FORM_ref_sup8
        @reader.read_u64
      when DW_FORM_data16
        @reader.read_u128
      when DW_FORM_flag
        @reader.read_u8 == 1
      when DW_FORM_flag_present
        true
      when DW_FORM_implicit_const
        implicit_const_value
      when DW_FORM_indirect
        read_attribute_value(@reader.read_uleb128, implicit_const_value)
      when DW_FORM_line_strp, DW_FORM_ref_addr, DW_FORM_sec_offset, DW_FORM_strp, DW_FORM_strp_sup
        @reader.read_ulong(@dwarf64 ? 8 : 4)
      when DW_FORM_sdata
        @reader.read_sleb128
      when DW_FORM_string
        @reader.read_string
      else
        raise Error.new("Unknown FORM value=#{form}")
      end
    end

    # Skips the current attribute's value as per the associated `Abbrev` FORM.
    def skip_attribute_value(form : UInt32) : Nil
      case form
      when DW_FORM_addr
        @reader.skip(address_size)
      when DW_FORM_addrx, DW_FORM_ref_udata, DW_FORM_rnglistx, DW_FORM_strx, DW_FORM_udata
        @reader.read_uleb128
      when DW_FORM_addrx1, DW_FORM_data1, DW_FORM_ref1, DW_FORM_strx1, DW_FORM_flag
        @reader.skip(1)
      when DW_FORM_addrx2, DW_FORM_data2, DW_FORM_ref2, DW_FORM_strx2
        @reader.skip(2)
      when DW_FORM_addrx3, DW_FORM_strx3
        @reader.skip(3)
      when DW_FORM_addrx4, DW_FORM_data4, DW_FORM_ref4, DW_FORM_strx4, DW_FORM_ref_sup4
        @reader.skip(4)
      when DW_FORM_block, DW_FORM_exprloc
        @reader.skip @reader.read_uleb128
      when DW_FORM_block2
        @reader.skip @reader.read_u16
      when DW_FORM_block4
        @reader.skip @reader.read_u32
      when DW_FORM_data8, DW_FORM_ref8, DW_FORM_ref_sig8, DW_FORM_ref_sup8
        @reader.skip(8)
      when DW_FORM_data16
        @reader.skip(16)
      when DW_FORM_flag_present, DW_FORM_implicit_const
        # nothing
      when DW_FORM_indirect
        skip_attribute_value(@reader.read_uleb128)
      when DW_FORM_line_strp, DW_FORM_ref_addr, DW_FORM_sec_offset, DW_FORM_strp, DW_FORM_strp_sup
        @reader.skip(@dwarf64 ? 8 : 4)
      when DW_FORM_sdata
        @reader.read_sleb128
      when DW_FORM_string
        @reader.read_string
      else
        raise Error.new("Unknown FORM value=#{form}")
      end
    end
  end

  # Iterates every `Info` (DIE) in *bytes*.
  def self.each_info(bytes : Bytes, &) : Nil
    reader = Reader.new(bytes)

    until reader.eof?
      unit_length = reader.read_u32
      dwarf64 = unit_length == 0xffffffff
      unit_length = reader.read_u64 if dwarf64
      offset = reader.pos
      version = reader.read_u16

      dwo_id = 0_u64
      type_signature = 0_u64
      type_offset = 0_u64

      if version >= 5
        unit_type = reader.read_u8
        address_size = reader.read_u8
        debug_abbrev_offset = reader.read_ulong(dwarf64 ? 8 : 4).to_u64

        case unit_type
        when DW_UT_compile, DW_UT_partial
          # no more headers
        when DW_UT_skeleton, DW_UT_split_compile
          dwo_id = reader.read_u64
        when DW_UT_type, DW_UT_split_type
          type_signature = reader.read_u64
          type_offset = reader.read_ulong(dwarf64 ? 8 : 4).to_u64
        end
      elsif version >= 2
        unit_type = 0_u8
        debug_abbrev_offset = reader.read_ulong(dwarf64 ? 8 : 4).to_u64
        address_size = reader.read_u8
      else
        raise Error.new("Unsupported version #{version}")
      end

      unit_size = offset + unit_length - reader.pos
      unit_bytes = reader.read(unit_size)

      yield Info.new(dwarf64, address_size, debug_abbrev_offset, unit_bytes,
        version, unit_type, dwo_id, type_signature, type_offset)
    end
  end
end
