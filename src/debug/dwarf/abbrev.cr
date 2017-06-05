require "../dwarf"

module Debug
  module DWARF
    enum TAG : UInt32
      ArrayType       = 0x01
      ClassType       = 0x02
      EntryPoint      = 0x03
      EnumerationType = 0x04
      FormalParameter = 0x05

      ImportedDeclaration    = 0x08
      Label                  = 0x0a
      LexicalBlock           = 0x0b
      Member                 = 0x0d
      PointerType            = 0x0f
      ReferenceType          = 0x10
      CompileUnit            = 0x11
      StringType             = 0x12
      StructureType          = 0x13
      SubroutineType         = 0x15
      Typedef                = 0x16
      UnionType              = 0x17
      UnspecifiedParameters  = 0x18
      Variant                = 0x19
      CommonBlock            = 0x1a
      CommonInclusion        = 0x1b
      Inheritance            = 0x1c
      InlinedSubroutine      = 0x1d
      Module                 = 0x1e
      PtrToMemberType        = 0x1f
      SetType                = 0x20
      SubrangeType           = 0x21
      WithStmt               = 0x22
      AccessDeclaration      = 0x23
      BaseType               = 0x24
      CatchBlock             = 0x25
      ConstType              = 0x26
      Constant               = 0x27
      Enumerator             = 0x28
      FileType               = 0x29
      Friend                 = 0x2a
      Namelist               = 0x2b
      NamelistItem           = 0x2c
      PackedType             = 0x2d
      Subprogram             = 0x2e
      TemplateTypeParameter  = 0x2f
      TemplateValueParameter = 0x30
      ThrownType             = 0x31
      TryBlock               = 0x32
      VariantPart            = 0x33
      Variable               = 0x34
      VolatileType           = 0x35
      DwarfProcedure         = 0x36
      RestrictType           = 0x37
      InterfaceType          = 0x38
      Namespace              = 0x39
      ImportedModule         = 0x3a
      UnspecifiedType        = 0x3b
      PartialUnit            = 0x3c
      ImportedUnit           = 0x3d
      Condition              = 0x3f
      SharedType             = 0x40
      TypeUnit               = 0x41
      RvalueReferenceType    = 0x42
      TemplateAlias          = 0x43
    end

    enum AT : UInt32
      DW_AT_sibling              = 0x01 # reference
      DW_AT_location             = 0x02 # exprloc, loclistptr
      DW_AT_name                 = 0x03 # string
      DW_AT_ordering             = 0x09 # constant
      DW_AT_byte_size            = 0x0b # constant, exprloc, reference
      DW_AT_bit_offset           = 0x0c # constant, exprloc, reference
      DW_AT_bit_size             = 0x0d # constant, exprloc, reference
      DW_AT_stmt_list            = 0x10 # lineptr
      DW_AT_low_pc               = 0x11 # address
      DW_AT_high_pc              = 0x12 # address, constant
      DW_AT_language             = 0x13 # constant
      DW_AT_discr                = 0x15 # reference
      DW_AT_discr_value          = 0x16 # constant
      DW_AT_visibility           = 0x17 # constant
      DW_AT_import               = 0x18 # reference
      DW_AT_string_length        = 0x19 # exprloc, loclistptr
      DW_AT_common_reference     = 0x1a # reference
      DW_AT_comp_dir             = 0x1b # string
      DW_AT_const_value          = 0x1c # block, constant, string
      DW_AT_containing_type      = 0x1d # reference
      DW_AT_default_value        = 0x1e # reference
      DW_AT_inline               = 0x20 # constant
      DW_AT_is_optional          = 0x21 # flag
      DW_AT_lower_bound          = 0x22 # constant, exprloc, reference
      DW_AT_producer             = 0x25 # string
      DW_AT_prototyped           = 0x27 # flag
      DW_AT_return_addr          = 0x2a # exprloc, loclistptr
      DW_AT_start_scope          = 0x2c # constant, rangelistptr
      DW_AT_bit_stride           = 0x2e # constant, exprloc, reference
      DW_AT_upper_bound          = 0x2f # constant, exprloc, reference
      DW_AT_abstract_origin      = 0x31 # reference
      DW_AT_accessibility        = 0x32 # constant
      DW_AT_address_class        = 0x33 # constant
      DW_AT_artificial           = 0x34 # flag
      DW_AT_base_types           = 0x35 # reference
      DW_AT_calling_convention   = 0x36 # constant
      DW_AT_count                = 0x37 # constant, exprloc, reference
      DW_AT_data_member_location = 0x38 # constant, exprloc, loclistptr
      DW_AT_decl_column          = 0x39 # constant
      DW_AT_decl_file            = 0x3a # constant
      DW_AT_decl_line            = 0x3b # constant
      DW_AT_declaration          = 0x3c # flag
      DW_AT_discr_list           = 0x3d # block
      DW_AT_encoding             = 0x3e # constant
      DW_AT_external             = 0x3f # flag
      DW_AT_frame_base           = 0x40 # exprloc, loclistptr
      DW_AT_friend               = 0x41 # reference
      DW_AT_identifier_case      = 0x42 # constant
      DW_AT_macro_info           = 0x43 # macptr
      DW_AT_namelist_item        = 0x44 # reference
      DW_AT_priority             = 0x45 # reference
      DW_AT_segment              = 0x46 # exprloc, loclistptr
      DW_AT_specification        = 0x47 # reference
      DW_AT_static_link          = 0x48 # exprloc, loclistptr
      DW_AT_type                 = 0x49 # reference
      DW_AT_use_location         = 0x4a # exprloc, loclistptr
      DW_AT_variable_parameter   = 0x4b # flag
      DW_AT_virtuality           = 0x4c # constant
      DW_AT_vtable_elem_location = 0x4d # exprloc, loclistptr
      DW_AT_allocated            = 0x4e # constant, exprloc, reference
      DW_AT_associated           = 0x4f # constant, exprloc, reference
      DW_AT_data_location        = 0x50 # exprloc
      DW_AT_byte_stride          = 0x51 # constant, exprloc, reference
      DW_AT_entry_pc             = 0x52 # address
      DW_AT_use_UTF8             = 0x53 # flag
      DW_AT_extension            = 0x54 # reference
      DW_AT_ranges               = 0x55 # rangelistptr
      DW_AT_trampoline           = 0x56 # address, flag, reference, string
      DW_AT_call_column          = 0x57 # constant
      DW_AT_call_file            = 0x58 # constant
      DW_AT_call_line            = 0x59 # constant
      DW_AT_description          = 0x5a # string
      DW_AT_binary_scale         = 0x5b # constant
      DW_AT_decimal_scale        = 0x5c # constant
      DW_AT_small                = 0x5d # reference
      DW_AT_decimal_sign         = 0x5e # constant
      DW_AT_digit_count          = 0x5f # constant
      DW_AT_picture_string       = 0x60 # string
      DW_AT_mutable              = 0x61 # flag
      DW_AT_threads_scaled       = 0x62 # flag
      DW_AT_explicit             = 0x63 # flag
      DW_AT_object_pointer       = 0x64 # reference
      DW_AT_endianity            = 0x65 # constant
      DW_AT_elemental            = 0x66 # flag
      DW_AT_pure                 = 0x67 # flag
      DW_AT_recursive            = 0x68 # flag
      DW_AT_signature            = 0x69 # reference
      DW_AT_main_subprogram      = 0x6a # flag
      DW_AT_data_bit_offset      = 0x6b # constant
      DW_AT_const_expr           = 0x6c # flag
      DW_AT_enum_class           = 0x6d # flag
      DW_AT_linkage_name         = 0x6e # string

      def unknown?
        AT.from_value?(value).nil?
      end
    end

    enum FORM : UInt32
      Addr        = 0x01 # address
      Block2      = 0x03 # block
      Block4      = 0x04 # block
      Data2       = 0x05 # constant
      Data4       = 0x06 # constant
      Data8       = 0x07 # constant
      String      = 0x08 # string
      Block       = 0x09 # block
      Block1      = 0x0a # block
      Data1       = 0x0b # constant
      Flag        = 0x0c # flag
      Sdata       = 0x0d # constant
      Strp        = 0x0e # string
      Udata       = 0x0f # constant
      RefAddr     = 0x10 # reference
      Ref1        = 0x11 # reference
      Ref2        = 0x12 # reference
      Ref4        = 0x13 # reference
      Ref8        = 0x14 # reference
      RefUdata    = 0x15 # reference
      Indirect    = 0x16 # (see Section 7.5.3)
      SecOffset   = 0x17 # lineptr, loclistptr, macptr, rangelistptr
      Exprloc     = 0x18 # exprloc
      FlagPresent = 0x19 # flag
      RefSig8     = 0x20 # reference
    end

    struct Abbrev
      record Attribute, at : AT, form : FORM

      property code : UInt32
      property tag : TAG
      property attributes : Array(Attribute)

      def initialize(@code, @tag, @children : Bool)
        @attributes = [] of Attribute
      end

      def children?
        @children
      end

      def self.read(io : IO::FileDescriptor, offset)
        abbreviations = [] of Abbrev

        io.seek(io.tell + offset)
        loop do
          code = DWARF.read_unsigned_leb128(io)
          break if code == 0

          tag = TAG.new(DWARF.read_unsigned_leb128(io))
          children = io.read_byte == 1
          abbrev = Abbrev.new(code, tag, children)

          loop do
            at = AT.new(DWARF.read_unsigned_leb128(io))
            form = FORM.new(DWARF.read_unsigned_leb128(io))
            break if at.value == 0 && form.value == 0
            abbrev.attributes << Attribute.new(at, form)
          end

          abbreviations << abbrev
        end

        abbreviations
      end
    end
  end
end
