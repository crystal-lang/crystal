module LLVM
  {% if LibLLVM.has_constant?(:AttributeRef) %}
    @[Flags]
    enum Attribute : UInt64
      Alignment = 1 << 0
      AllocSize = 1 << 1
      AlwaysInline = 1 << 2
      ArgMemOnly = 1 << 3
      Builtin = 1 << 4
      ByVal = 1 << 5
      Cold = 1 << 6
      Convergent = 1 << 7
      Dereferenceable = 1 << 8
      DereferenceableOrNull = 1 << 9
      InAlloca = 1 << 10
      InReg = 1 << 11
      InaccessibleMemOnly = 1 << 12
      InaccessibleMemOrArgMemOnly = 1 << 13
      InlineHint = 1 << 14
      JumpTable = 1 << 15
      MinSize = 1 << 16
      Naked = 1 << 17
      Nest = 1 << 18
      NoAlias = 1 << 19
      NoBuiltin = 1 << 20
      NoCapture = 1 << 21
      NoDuplicate = 1 << 22
      NoImplicitFloat = 1 << 23
      NoInline = 1 << 24
      NoRecurse = 1 << 25
      NoRedZone = 1 << 26
      NoReturn = 1 << 27
      NoUnwind = 1 << 28
      NonLazyBind = 1 << 29
      NonNull = 1 << 30
      OptimizeForSize = 1 << 31
      OptimizeNone = 1 << 32
      ReadNone = 1 << 33
      ReadOnly = 1 << 34
      Returned = 1 << 35
      ReturnsTwice = 1 << 36
      SExt = 1 << 37
      SafeStack = 1 << 38
      SanitizeAddress = 1 << 39
      SanitizeMemory = 1 << 40
      SanitizeThread = 1 << 41
      StackAlignment = 1 << 42
      StackProtect = 1 << 43
      StackProtectReq = 1 << 44
      StackProtectStrong = 1 << 45
      StructRet = 1 << 46
      SwiftError = 1 << 47
      SwiftSelf = 1 << 48
      UWTable = 1 << 49
      WriteOnly = 1 << 50
      ZExt = 1 << 51

      @@kind_ids = load_llvm_kinds_from_names.as(Hash(Attribute, UInt32))

      def each_kind(&block)
        return if value == 0
        \{% for member in @type.constants %}
          \{% if member.stringify != "All" %}
            if includes?(\{{@type}}::\{{member}})
              yield @@kind_ids[\{{@type}}::\{{member}}]
            end
          \{% end %}
        \{% end %}
      end

      private def self.kind_for_name(name : String)
        LibLLVM.get_enum_attribute_kind_for_name(name, name.bytesize)
      end

      private def self.load_llvm_kinds_from_names
        kinds = {} of Attribute => UInt32
        kinds[Alignment]                   = kind_for_name("align")
        kinds[AllocSize]                   = kind_for_name("allocsize")
        kinds[AlwaysInline]                = kind_for_name("alwaysinline")
        kinds[ArgMemOnly]                  = kind_for_name("argmemonly")
        kinds[Builtin]                     = kind_for_name("builtin")
        kinds[ByVal]                       = kind_for_name("byval")
        kinds[Cold]                        = kind_for_name("cold")
        kinds[Convergent]                  = kind_for_name("convergent")
        kinds[Dereferenceable]             = kind_for_name("dereferenceable")
        kinds[DereferenceableOrNull]       = kind_for_name("dereferenceable_or_null")
        kinds[InAlloca]                    = kind_for_name("inalloca")
        kinds[InReg]                       = kind_for_name("inreg")
        kinds[InaccessibleMemOnly]         = kind_for_name("inaccessiblememonly")
        kinds[InaccessibleMemOrArgMemOnly] = kind_for_name("inaccessiblemem_or_argmemonly")
        kinds[InlineHint]                  = kind_for_name("inlinehint")
        kinds[JumpTable]                   = kind_for_name("jumptable")
        kinds[MinSize]                     = kind_for_name("minsize")
        kinds[Naked]                       = kind_for_name("naked")
        kinds[Nest]                        = kind_for_name("nest")
        kinds[NoAlias]                     = kind_for_name("noalias")
        kinds[NoBuiltin]                   = kind_for_name("nobuiltin")
        kinds[NoCapture]                   = kind_for_name("nocapture")
        kinds[NoDuplicate]                 = kind_for_name("noduplicate")
        kinds[NoImplicitFloat]             = kind_for_name("noimplicitfloat")
        kinds[NoInline]                    = kind_for_name("noinline")
        kinds[NoRecurse]                   = kind_for_name("norecurse")
        kinds[NoRedZone]                   = kind_for_name("noredzone")
        kinds[NoReturn]                    = kind_for_name("noreturn")
        kinds[NoUnwind]                    = kind_for_name("nounwind")
        kinds[NonLazyBind]                 = kind_for_name("nonlazybind")
        kinds[NonNull]                     = kind_for_name("nonnull")
        kinds[OptimizeForSize]             = kind_for_name("optsize")
        kinds[OptimizeNone]                = kind_for_name("optnone")
        kinds[ReadNone]                    = kind_for_name("readnone")
        kinds[ReadOnly]                    = kind_for_name("readonly")
        kinds[Returned]                    = kind_for_name("returned")
        kinds[ReturnsTwice]                = kind_for_name("returns_twice")
        kinds[SExt]                        = kind_for_name("signext")
        kinds[SafeStack]                   = kind_for_name("safestack")
        kinds[SanitizeAddress]             = kind_for_name("sanitize_address")
        kinds[SanitizeMemory]              = kind_for_name("sanitize_memory")
        kinds[SanitizeThread]              = kind_for_name("sanitize_thread")
        kinds[StackAlignment]              = kind_for_name("alignstack")
        kinds[StackProtect]                = kind_for_name("ssp")
        kinds[StackProtectReq]             = kind_for_name("sspreq")
        kinds[StackProtectStrong]          = kind_for_name("sspstrong")
        kinds[StructRet]                   = kind_for_name("sret")
        kinds[SwiftError]                  = kind_for_name("swifterror")
        kinds[SwiftSelf]                   = kind_for_name("swiftself")
        kinds[UWTable]                     = kind_for_name("uwtable")
        kinds[WriteOnly]                   = kind_for_name("writeonly")
        kinds[ZExt]                        = kind_for_name("zeroext")
        kinds
      end

      def self.kind_for(member)
        @@kind_ids[member]
      end

      def self.from_kind(kind)
        @@kind_ids.key(kind)
      end
    end
  {% else %}
    @[Flags]
    enum Attribute : UInt32
      ZExt            = 1 << 0
      SExt            = 1 << 1
      NoReturn        = 1 << 2
      InReg           = 1 << 3
      StructRet       = 1 << 4
      NoUnwind        = 1 << 5
      NoAlias         = 1 << 6
      ByVal           = 1 << 7
      Nest            = 1 << 8
      ReadNone        = 1 << 9
      ReadOnly        = 1 << 10
      NoInline        = 1 << 11
      AlwaysInline    = 1 << 12
      OptimizeForSize = 1 << 13
      StackProtect    = 1 << 14
      StackProtectReq = 1 << 15
      Alignment       = 31 << 16
      NoCapture       = 1 << 21
      NoRedZone       = 1 << 22
      NoImplicitFloat = 1 << 23
      Naked           = 1 << 24
      InlineHint      = 1 << 25
      StackAlignment  = 7 << 26
      ReturnsTwice    = 1 << 29
      UWTable         = 1 << 30
      NonLazyBind     = 1 << 31
      # AddressSafety = 1_u64 << 32,
      # StackProtectStrong = 1_u64 << 33
    end
  {% end %}

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
    DLLImport
    DLLExport
    ExternalWeak
    Ghost
    Common
    LinkerPrivate
    LinkerPrivateWeak
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

  enum AtomicOrdering
    NotAtomic              = 0
    Unordered              = 1
    Monotonic              = 2
    Acquire                = 4
    Release                = 5
    AcquireRelease         = 6
    SequentiallyConsistent = 7
  end

  enum AtomicRMWBinOp
    Xchg
    Add
    Sub
    And
    Nand
    Or
    Xor
    Max
    Min
    UMax
    UMin
  end

  enum DIFlags : UInt32
    Zero                = 0
    Private             = 1
    Protected           = 2
    Public              = 3
    FwdDecl             = 1 << 2
    AppleBlock          = 1 << 3
    BlockByrefStruct    = 1 << 4
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
    MainSubprogram      = 1 << 21
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

  enum ModuleFlag : Int32
    Warning = 2
  end
end
