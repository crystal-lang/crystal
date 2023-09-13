module LLVM
  @[Flags]
  enum Attribute : UInt64
    Alignment
    AllocSize
    AlwaysInline
    ArgMemOnly
    Builtin
    ByVal
    Cold
    Convergent
    Dereferenceable
    DereferenceableOrNull
    InAlloca
    InReg
    InaccessibleMemOnly
    InaccessibleMemOrArgMemOnly
    InlineHint
    JumpTable
    MinSize
    Naked
    Nest
    NoAlias
    NoBuiltin
    NoCapture
    NoDuplicate
    NoFree
    NoImplicitFloat
    NoInline
    NoRecurse
    NoRedZone
    NoReturn
    NoSync
    NoUnwind
    NonLazyBind
    NonNull
    OptimizeForSize
    OptimizeNone
    ReadNone
    ReadOnly
    Returned
    ImmArg
    ReturnsTwice
    SExt
    SafeStack
    SanitizeAddress
    SanitizeMemory
    SanitizeThread
    StackAlignment
    StackProtect
    StackProtectReq
    StackProtectStrong
    StructRet
    SwiftError
    SwiftSelf
    UWTable
    WillReturn
    WriteOnly
    ZExt

    @@kind_ids = load_llvm_kinds_from_names.as(Hash(Attribute, UInt32))
    @@typed_attrs = load_llvm_typed_attributes.as(Array(Attribute))

    def each_kind(& : UInt32 ->)
      each do |member|
        yield @@kind_ids[member]
      end
    end

    private def self.kind_for_name(name : String)
      LibLLVM.get_enum_attribute_kind_for_name(name, name.bytesize)
    end

    private def self.load_llvm_kinds_from_names
      kinds = {} of Attribute => UInt32
      kinds[Alignment] = kind_for_name("align")
      kinds[AllocSize] = kind_for_name("allocsize")
      kinds[AlwaysInline] = kind_for_name("alwaysinline")
      kinds[ArgMemOnly] = kind_for_name("argmemonly")
      kinds[Builtin] = kind_for_name("builtin")
      kinds[ByVal] = kind_for_name("byval")
      kinds[Cold] = kind_for_name("cold")
      kinds[Convergent] = kind_for_name("convergent")
      kinds[Dereferenceable] = kind_for_name("dereferenceable")
      kinds[DereferenceableOrNull] = kind_for_name("dereferenceable_or_null")
      kinds[InAlloca] = kind_for_name("inalloca")
      kinds[InReg] = kind_for_name("inreg")
      kinds[InaccessibleMemOnly] = kind_for_name("inaccessiblememonly")
      kinds[InaccessibleMemOrArgMemOnly] = kind_for_name("inaccessiblemem_or_argmemonly")
      kinds[InlineHint] = kind_for_name("inlinehint")
      kinds[JumpTable] = kind_for_name("jumptable")
      kinds[MinSize] = kind_for_name("minsize")
      kinds[Naked] = kind_for_name("naked")
      kinds[Nest] = kind_for_name("nest")
      kinds[NoAlias] = kind_for_name("noalias")
      kinds[NoBuiltin] = kind_for_name("nobuiltin")
      kinds[NoCapture] = kind_for_name("nocapture")
      kinds[NoDuplicate] = kind_for_name("noduplicate")
      kinds[NoFree] = kind_for_name("nofree")
      kinds[NoImplicitFloat] = kind_for_name("noimplicitfloat")
      kinds[NoInline] = kind_for_name("noinline")
      kinds[NoRecurse] = kind_for_name("norecurse")
      kinds[NoRedZone] = kind_for_name("noredzone")
      kinds[NoReturn] = kind_for_name("noreturn")
      kinds[NoSync] = kind_for_name("nosync")
      kinds[NoUnwind] = kind_for_name("nounwind")
      kinds[NonLazyBind] = kind_for_name("nonlazybind")
      kinds[NonNull] = kind_for_name("nonnull")
      kinds[OptimizeForSize] = kind_for_name("optsize")
      kinds[OptimizeNone] = kind_for_name("optnone")
      kinds[ReadNone] = kind_for_name("readnone")
      kinds[ReadOnly] = kind_for_name("readonly")
      kinds[Returned] = kind_for_name("returned")
      kinds[ImmArg] = kind_for_name("immarg")
      kinds[ReturnsTwice] = kind_for_name("returns_twice")
      kinds[SExt] = kind_for_name("signext")
      kinds[SafeStack] = kind_for_name("safestack")
      kinds[SanitizeAddress] = kind_for_name("sanitize_address")
      kinds[SanitizeMemory] = kind_for_name("sanitize_memory")
      kinds[SanitizeThread] = kind_for_name("sanitize_thread")
      kinds[StackAlignment] = kind_for_name("alignstack")
      kinds[StackProtect] = kind_for_name("ssp")
      kinds[StackProtectReq] = kind_for_name("sspreq")
      kinds[StackProtectStrong] = kind_for_name("sspstrong")
      kinds[StructRet] = kind_for_name("sret")
      kinds[SwiftError] = kind_for_name("swifterror")
      kinds[SwiftSelf] = kind_for_name("swiftself")
      kinds[UWTable] = kind_for_name("uwtable")
      kinds[WillReturn] = kind_for_name("willreturn")
      kinds[WriteOnly] = kind_for_name("writeonly")
      kinds[ZExt] = kind_for_name("zeroext")
      kinds
    end

    private def self.load_llvm_typed_attributes
      typed_attrs = [] of Attribute

      unless LibLLVM::IS_LT_120
        # LLVM 12 introduced mandatory type parameters for byval and sret
        typed_attrs << ByVal
        typed_attrs << StructRet
      end

      unless LibLLVM::IS_LT_130
        # LLVM 13 manadates type params for inalloca
        typed_attrs << InAlloca
      end

      typed_attrs
    end

    def self.kind_for(member)
      @@kind_ids[member]
    end

    def self.from_kind(kind)
      @@kind_ids.key_for(kind)
    end

    def self.requires_type?(kind)
      member = from_kind(kind)
      @@typed_attrs.includes?(member)
    end
  end

  # Attribute index are either ReturnIndex (0), FunctionIndex (-1) or a
  # parameter number ranging from 1 to N.
  enum AttributeIndex : UInt32
    ReturnIndex   = 0_u32
    FunctionIndex = ~0_u32
  end

  enum Linkage
    External
    AvailableExternally
    LinkOnceAny
    LinkOnceODR
    LinkOnceODRAutoHide
    WeakAny
    WeakODR
    Appending
    Internal
    Private
    DLLImport # obsolete
    DLLExport # obsolete
    ExternalWeak
    Ghost
    Common
    LinkerPrivate
    LinkerPrivateWeak
  end

  enum DLLStorageClass
    Default

    # Function to be imported from DLL.
    DLLImport

    # Function to be accessible from DLL.
    DLLExport
  end

  enum IntPredicate
    EQ  = 32
    NE
    UGT
    UGE
    ULT
    ULE
    SGT
    SGE
    SLT
    SLE
  end

  enum RealPredicate
    PredicateFalse
    OEQ
    OGT
    OGE
    OLT
    OLE
    ONE
    ORD
    UNO
    UEQ
    UGT
    UGE
    ULT
    ULE
    UNE
    PredicateTrue
  end

  struct Type
    enum Kind
      Void
      Half
      Float
      Double
      X86_FP80
      FP128
      PPC_FP128
      Label
      Integer
      Function
      Struct
      Array
      Pointer
      Vector
      Metadata
      X86_MMX
    end
  end

  enum CodeGenOptLevel
    None
    Less
    Default
    Aggressive
  end

  enum CodeGenFileType
    AssemblyFile
    ObjectFile
  end

  enum RelocMode
    Default
    Static
    PIC
    DynamicNoPIC
  end

  enum CodeModel
    Default
    JITDefault
    Small
    Kernel
    Medium
    Large
  end

  enum VerifierFailureAction
    AbortProcessAction # verifier will print to stderr and abort()
    PrintMessageAction # verifier will print to stderr and return 1
    ReturnStatusAction # verifier will just return 1
  end

  enum CallConvention
    C            =  0
    Fast         =  8
    Cold         =  9
    WebKit_JS    = 12
    AnyReg       = 13
    X86_StdCall  = 64
    X86_FastCall = 65
  end

  enum DwarfTag
    AutoVariable = 0x100
  end

  enum DwarfTypeEncoding
    Address        = 0x01
    Boolean        = 0x02
    ComplexFloat   = 0x03
    Float          = 0x04
    Signed         = 0x05
    SignedChar     = 0x06
    Unsigned       = 0x07
    UnsignedChar   = 0x08
    ImaginaryFloat = 0x09
    PackedDecimal  = 0x0a
    NumericString  = 0x0b
    Edited         = 0x0c
    SignedFixed    = 0x0d
    UnsignedFixed  = 0x0e
    DecimalFloat   = 0x0f
    Utf            = 0x10
    LoUser         = 0x80
    HiUser         = 0xff
  end

  enum DwarfSourceLanguage
    C89
    C
    Ada83
    C_plus_plus
    Cobol74
    Cobol85
    Fortran77
    Fortran90
    Pascal83
    Modula2

    # New in DWARF v3:

    Java
    C99
    Ada95
    Fortran95
    PLI
    ObjC
    ObjC_plus_plus
    UPC
    D

    # New in DWARF v4:

    Python

    # New in DWARF v5:

    OpenCL
    Go
    Modula3
    Haskell
    C_plus_plus_03
    C_plus_plus_11
    OCaml
    Rust
    C11
    Swift
    Julia
    Dylan
    C_plus_plus_14
    Fortran03
    Fortran08
    RenderScript
    BLISS

    {% unless LibLLVM::IS_LT_160 %}
      Kotlin
      Zig
      Crystal
      C_plus_plus_17
      C_plus_plus_20
      C17
      Fortran18
      Ada2005
      Ada2012
    {% end %}

    # Vendor extensions:

    Mips_Assembler
    GOOGLE_RenderScript
    BORLAND_Delphi
  end

  enum DIFlags : UInt32
    Zero       = 0
    Private    = 1
    Protected  = 2
    Public     = 3
    FwdDecl    = 1 << 2
    AppleBlock = 1 << 3

    {% if LibLLVM::IS_LT_100 %}
      BlockByrefStruct = 1 << 4
    {% else %}
      ReservedBit4 = 1 << 4
    {% end %}

    Virtual             = 1 << 5
    Artificial          = 1 << 6
    Explicit            = 1 << 7
    Prototyped          = 1 << 8
    ObjcClassComplete   = 1 << 9
    ObjectPointer       = 1 << 10
    Vector              = 1 << 11
    StaticMember        = 1 << 12
    LValueReference     = 1 << 13
    RValueReference     = 1 << 14
    ExternalTypeRef     = 1 << 15
    SingleInheritance   = 1 << 16
    MultipleInheritance = 2 << 16
    VirtualInheritance  = 3 << 16
    IntroducedVirtual   = 1 << 18
    BitField            = 1 << 19
    NoReturn            = 1 << 20

    {% if LibLLVM::IS_LT_90 %}
      MainSubprogram = 1 << 21
    {% end %}

    PassByValue         = 1 << 22
    TypePassByReference = 1 << 23
    EnumClass           = 1 << 24
    Thunk               = 1 << 25

    {% if LibLLVM::IS_LT_90 %}
      Trivial = 1 << 26
    {% else %}
      NonTrivial = 1 << 26
    {% end %}

    BigEndian    = 1 << 27
    LittleEndian = 1 << 28
  end

  struct Value
    enum Kind
      Argument
      BasicBlock
      MemoryUse
      MemoryDef
      MemoryPhi

      Function
      GlobalAlias
      GlobalIFunc
      GlobalVariable
      BlockAddress
      ConstantExpr
      ConstantArray
      ConstantStruct
      ConstantVector

      UndefValue
      ConstantAggregateZero
      ConstantDataArray
      ConstantDataVector
      ConstantInt
      ConstantFP
      ConstantPointerNull
      ConstantTokenNone

      MetadataAsValue
      InlineAsm

      Instruction
    end
  end

  struct Metadata
    enum Type : UInt32
      Dbg                   =  0 # "dbg"
      Tbaa                  =  1 # "tbaa"
      Prof                  =  2 # "prof"
      Fpmath                =  3 # "fpmath"
      Range                 =  4 # "range"
      TbaaStruct            =  5 # "tbaa.struct"
      InvariantLoad         =  6 # "invariant.load"
      AliasScope            =  7 # "alias.scope"
      Noalias               =  8 # "noalias"
      Nontemporal           =  9 # "nontemporal"
      MemParallelLoopAccess = 10 # "llvm.mem.parallel_loop_access"
      Nonnull               = 11 # "nonnull"
      Dereferenceable       = 12 # "dereferenceable"
      DereferenceableOrNull = 13 # "dereferenceable_or_null"
      MakeImplicit          = 14 # "make.implicit"
      Unpredictable         = 15 # "unpredictable"
      InvariantGroup        = 16 # "invariant.group"
      Align                 = 17 # "align"
      Loop                  = 18 # "llvm.loop"
      Type                  = 19 # "type"
      SectionPrefix         = 20 # "section_prefix"
      AbsoluteSymbol        = 21 # "absolute_symbol"
      Associated            = 22 # "associated"
      Callees               = 23 # "callees"
      IrrLoop               = 24 # "irr_loop"
      AccessGroup           = 25 # "llvm.access.group"
      Callback              = 26 # "callback"
      PreserveAccessIndex   = 27 # "llvm.preserve.*.access.index"
    end
  end

  enum UWTableKind
    None    = 0 # No unwind table requested
    Sync    = 1 # "Synchronous" unwind tables
    Async   = 2 # "Asynchronous" unwind tables (instr precise)
    Default = 2
  end
end

require "./enums/*"
