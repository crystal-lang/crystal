{% skip_file unless LibLLVM::VERSION_MAJOR == 11 %}

# WARNING: This enum is marked as unstable by LLVM. The following members are
# valid for LLVM 11. Refer to `src/llvm/enums/attribute_kind/llvm_*.cr` to see
# if a particular member was added or removed.
enum LLVM::AttributeKind : UInt32
  AlwaysInline                =  1 # EnumAttr
  ArgMemOnly                  =  2 # EnumAttr
  Builtin                     =  3 # EnumAttr
  Cold                        =  4 # EnumAttr
  Convergent                  =  5 # EnumAttr
  ImmArg                      =  6 # EnumAttr
  InAlloca                    =  7 # EnumAttr
  InReg                       =  8 # EnumAttr
  InaccessibleMemOnly         =  9 # EnumAttr
  InaccessibleMemOrArgMemOnly = 10 # EnumAttr
  InlineHint                  = 11 # EnumAttr
  JumpTable                   = 12 # EnumAttr
  MinSize                     = 13 # EnumAttr
  Naked                       = 14 # EnumAttr
  Nest                        = 15 # EnumAttr
  NoAlias                     = 16 # EnumAttr
  NoBuiltin                   = 17 # EnumAttr
  NoCapture                   = 18 # EnumAttr
  NoCfCheck                   = 19 # EnumAttr
  NoDuplicate                 = 20 # EnumAttr
  NoFree                      = 21 # EnumAttr
  NoImplicitFloat             = 22 # EnumAttr
  NoInline                    = 23 # EnumAttr
  NoMerge                     = 24 # EnumAttr
  NoRecurse                   = 25 # EnumAttr
  NoRedZone                   = 26 # EnumAttr
  NoReturn                    = 27 # EnumAttr
  NoSync                      = 28 # EnumAttr
  NoUndef                     = 29 # EnumAttr
  NoUnwind                    = 30 # EnumAttr
  NonLazyBind                 = 31 # EnumAttr
  NonNull                     = 32 # EnumAttr
  NullPointerIsValid          = 33 # EnumAttr
  OptForFuzzing               = 34 # EnumAttr
  OptimizeForSize             = 35 # EnumAttr
  OptimizeNone                = 36 # EnumAttr
  ReadNone                    = 37 # EnumAttr
  ReadOnly                    = 38 # EnumAttr
  Returned                    = 39 # EnumAttr
  ReturnsTwice                = 40 # EnumAttr
  SExt                        = 41 # EnumAttr
  SafeStack                   = 42 # EnumAttr
  SanitizeAddress             = 43 # EnumAttr
  SanitizeHWAddress           = 44 # EnumAttr
  SanitizeMemTag              = 45 # EnumAttr
  SanitizeMemory              = 46 # EnumAttr
  SanitizeThread              = 47 # EnumAttr
  ShadowCallStack             = 48 # EnumAttr
  Speculatable                = 49 # EnumAttr
  SpeculativeLoadHardening    = 50 # EnumAttr
  StackProtect                = 51 # EnumAttr
  StackProtectReq             = 52 # EnumAttr
  StackProtectStrong          = 53 # EnumAttr
  StrictFP                    = 54 # EnumAttr
  StructRet                   = 55 # EnumAttr
  SwiftError                  = 56 # EnumAttr
  SwiftSelf                   = 57 # EnumAttr
  UWTable                     = 58 # EnumAttr
  WillReturn                  = 59 # EnumAttr
  WriteOnly                   = 60 # EnumAttr
  ZExt                        = 61 # EnumAttr
  ByVal                       = 62 # TypeAttr
  Preallocated                = 63 # TypeAttr
  Alignment                   = 64 # IntAttr
  AllocSize                   = 65 # IntAttr
  Dereferenceable             = 66 # IntAttr
  DereferenceableOrNull       = 67 # IntAttr
  StackAlignment              = 68 # IntAttr
end
