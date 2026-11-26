{% skip_file unless LibLLVM::VERSION_MAJOR == 9 %}

# WARNING: This enum is marked as unstable by LLVM. The following members are
# valid for LLVM 9. Refer to `src/llvm/enums/attribute_kind/llvm_*.cr` to see
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
  ImmArg                      = 11 # EnumAttr
  InAlloca                    = 12 # EnumAttr
  InReg                       = 13 # EnumAttr
  InaccessibleMemOnly         = 14 # EnumAttr
  InaccessibleMemOrArgMemOnly = 15 # EnumAttr
  InlineHint                  = 16 # EnumAttr
  JumpTable                   = 17 # EnumAttr
  MinSize                     = 18 # EnumAttr
  Naked                       = 19 # EnumAttr
  Nest                        = 20 # EnumAttr
  NoAlias                     = 21 # EnumAttr
  NoBuiltin                   = 22 # EnumAttr
  NoCapture                   = 23 # EnumAttr
  NoCfCheck                   = 24 # EnumAttr
  NoDuplicate                 = 25 # EnumAttr
  NoFree                      = 26 # EnumAttr
  NoImplicitFloat             = 27 # EnumAttr
  NoInline                    = 28 # EnumAttr
  NoRecurse                   = 29 # EnumAttr
  NoRedZone                   = 30 # EnumAttr
  NoReturn                    = 31 # EnumAttr
  NoSync                      = 32 # EnumAttr
  NoUnwind                    = 33 # EnumAttr
  NonLazyBind                 = 34 # EnumAttr
  NonNull                     = 35 # EnumAttr
  OptForFuzzing               = 36 # EnumAttr
  OptimizeForSize             = 37 # EnumAttr
  OptimizeNone                = 38 # EnumAttr
  ReadNone                    = 39 # EnumAttr
  ReadOnly                    = 40 # EnumAttr
  Returned                    = 41 # EnumAttr
  ReturnsTwice                = 42 # EnumAttr
  SExt                        = 43 # EnumAttr
  SafeStack                   = 44 # EnumAttr
  SanitizeAddress             = 45 # EnumAttr
  SanitizeHWAddress           = 46 # EnumAttr
  SanitizeMemTag              = 47 # EnumAttr
  SanitizeMemory              = 48 # EnumAttr
  SanitizeThread              = 49 # EnumAttr
  ShadowCallStack             = 50 # EnumAttr
  Speculatable                = 51 # EnumAttr
  SpeculativeLoadHardening    = 52 # EnumAttr
  StackAlignment              = 53 # EnumAttr
  StackProtect                = 54 # EnumAttr
  StackProtectReq             = 55 # EnumAttr
  StackProtectStrong          = 56 # EnumAttr
  StrictFP                    = 57 # EnumAttr
  StructRet                   = 58 # EnumAttr
  SwiftError                  = 59 # EnumAttr
  SwiftSelf                   = 60 # EnumAttr
  UWTable                     = 61 # EnumAttr
  WillReturn                  = 62 # EnumAttr
  WriteOnly                   = 63 # EnumAttr
  ZExt                        = 64 # EnumAttr
end
