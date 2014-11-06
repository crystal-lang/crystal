module LLVM
  @[Flags]
  enum Attribute
    ZExt            =  1 << 0
    SExt            =  1 << 1
    NoReturn        =  1 << 2
    InReg           =  1 << 3
    StructRet       =  1 << 4
    NoUnwind        =  1 << 5
    NoAlias         =  1 << 6
    ByVal           =  1 << 7
    Nest            =  1 << 8
    ReadNone        =  1 << 9
    ReadOnly        =  1 << 10
    NoInline        =  1 << 11
    AlwaysInline    =  1 << 12
    OptimizeForSize =  1 << 13
    StackProtect    =  1 << 14
    StackProtectReq =  1 << 15
    Alignment       = 31 << 16
    NoCapture       =  1 << 21
    NoRedZone       =  1 << 22
    NoImplicitFloat =  1 << 23
    Naked           =  1 << 24
    InlineHint      =  1 << 25
    StackAlignment  =  7 << 26
    ReturnsTwice    =  1 << 29
    UWTable         =  1 << 30
    NonLazyBind     =  1 << 31
    # AddressSafety = 1_u64 << 32,
    # StackProtectStrong = 1_u64 << 33
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
    EQ = 32
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
    AbortProcessAction   # verifier will print to stderr and abort()
    PrintMessageAction   # verifier will print to stderr and return 1
    ReturnStatusAction   # verifier will just return 1
  end

  enum CallConvention
    C           = 0
    Fast        = 8
    Cold        = 9
    WebKitJS    = 12
    AnyReg      = 13
    X86Std  = 64
    X86Fastcall = 65
  end
end
