{% skip_file unless LibLLVM::VERSION_MAJOR == 8 %}

# WARNING: This enum is marked as unstable by LLVM. The following members are
# valid for LLVM 8. Refer to `src/llvm/enums/attribute_kind/llvm_*.cr` to see
# if a particular member was added or removed.
enum LLVM::AttributeKind : UInt32
  Alignment                   =  1 # EnumAttr
  AllocSize                   =  2 # EnumAttr
  AlwaysInline                =  3 # EnumAttr
  ArgMemOnly                  =  4 # EnumAttr
  Builtin                     =  5 # EnumAttr
  ByVal                       =  6 # EnumAttr
  Cold                        =  7 # EnumAttr
  Convergent                  =  8 # EnumAttr
  Dereferenceable             =  9 # EnumAttr
  DereferenceableOrNull       = 10 # EnumAttr
  InAlloca                    = 11 # EnumAttr
  InReg                       = 12 # EnumAttr
  InaccessibleMemOnly         = 13 # EnumAttr
  InaccessibleMemOrArgMemOnly = 14 # EnumAttr
  InlineHint                  = 15 # EnumAttr
  JumpTable                   = 16 # EnumAttr
  MinSize                     = 17 # EnumAttr
  Naked                       = 18 # EnumAttr
  Nest                        = 19 # EnumAttr
  NoAlias                     = 20 # EnumAttr
  NoBuiltin                   = 21 # EnumAttr
  NoCapture                   = 22 # EnumAttr
  NoCfCheck                   = 23 # EnumAttr
  NoDuplicate                 = 24 # EnumAttr
  NoImplicitFloat             = 25 # EnumAttr
  NoInline                    = 26 # EnumAttr
  NoRecurse                   = 27 # EnumAttr
  NoRedZone                   = 28 # EnumAttr
  NoReturn                    = 29 # EnumAttr
  NoUnwind                    = 30 # EnumAttr
  NonLazyBind                 = 31 # EnumAttr
  NonNull                     = 32 # EnumAttr
  OptForFuzzing               = 33 # EnumAttr
  OptimizeForSize             = 34 # EnumAttr
  OptimizeNone                = 35 # EnumAttr
  ReadNone                    = 36 # EnumAttr
  ReadOnly                    = 37 # EnumAttr
  Returned                    = 38 # EnumAttr
  ReturnsTwice                = 39 # EnumAttr
  SExt                        = 40 # EnumAttr
  SafeStack                   = 41 # EnumAttr
  SanitizeAddress             = 42 # EnumAttr
  SanitizeHWAddress           = 43 # EnumAttr
  SanitizeMemory              = 44 # EnumAttr
  SanitizeThread              = 45 # EnumAttr
  ShadowCallStack             = 46 # EnumAttr
  Speculatable                = 47 # EnumAttr
  SpeculativeLoadHardening    = 48 # EnumAttr
  StackAlignment              = 49 # EnumAttr
  StackProtect                = 50 # EnumAttr
  StackProtectReq             = 51 # EnumAttr
  StackProtectStrong          = 52 # EnumAttr
  StrictFP                    = 53 # EnumAttr
  StructRet                   = 54 # EnumAttr
  SwiftError                  = 55 # EnumAttr
  SwiftSelf                   = 56 # EnumAttr
  UWTable                     = 57 # EnumAttr
  WriteOnly                   = 58 # EnumAttr
  ZExt                        = 59 # EnumAttr
end
