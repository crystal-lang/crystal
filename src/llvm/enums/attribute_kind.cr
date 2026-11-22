module LLVM
  private ATTRIBUTE_KIND_VALUES = {} of _ => _
end

require "./attribute_kind/*"

enum LLVM::AttributeKind : UInt32
  None = 0

  # The following is an alphabetically sorted list of every attribute ever
  # defined by LLVM. Undefined values in the current LLVM version are 0, thus
  # equal to `AttributeKind::None`, consistent with
  # `LibLLVM.get_enum_attribute_kind_for_name`. Wrappers passing kind IDs to
  # LLVM should ensure that they are not equal to `None`.

  {% begin %}
    Alignment                       = {{ ATTRIBUTE_KIND_VALUES["Alignment"] || 0 }}
    AllocAlign                      = {{ ATTRIBUTE_KIND_VALUES["AllocAlign"] || 0 }}
    AllocKind                       = {{ ATTRIBUTE_KIND_VALUES["AllocKind"] || 0 }}
    AllocSize                       = {{ ATTRIBUTE_KIND_VALUES["AllocSize"] || 0 }}
    AllocatedPointer                = {{ ATTRIBUTE_KIND_VALUES["AllocatedPointer"] || 0 }}
    AlwaysInline                    = {{ ATTRIBUTE_KIND_VALUES["AlwaysInline"] || 0 }}
    ArgMemOnly                      = {{ ATTRIBUTE_KIND_VALUES["ArgMemOnly"] || 0 }}
    Builtin                         = {{ ATTRIBUTE_KIND_VALUES["Builtin"] || 0 }}
    ByRef                           = {{ ATTRIBUTE_KIND_VALUES["ByRef"] || 0 }}
    ByVal                           = {{ ATTRIBUTE_KIND_VALUES["ByVal"] || 0 }}
    Captures                        = {{ ATTRIBUTE_KIND_VALUES["Captures"] || 0 }}
    Cold                            = {{ ATTRIBUTE_KIND_VALUES["Cold"] || 0 }}
    Convergent                      = {{ ATTRIBUTE_KIND_VALUES["Convergent"] || 0 }}
    CoroDestroyOnlyWhenComplete     = {{ ATTRIBUTE_KIND_VALUES["CoroDestroyOnlyWhenComplete"] || 0 }}
    CoroElideSafe                   = {{ ATTRIBUTE_KIND_VALUES["CoroElideSafe"] || 0 }}
    DeadOnReturn                    = {{ ATTRIBUTE_KIND_VALUES["DeadOnReturn"] || 0 }}
    DeadOnUnwind                    = {{ ATTRIBUTE_KIND_VALUES["DeadOnUnwind"] || 0 }}
    DenormalFPEnv                   = {{ ATTRIBUTE_KIND_VALUES["DenormalFPEnv"] || 0 }}
    Dereferenceable                 = {{ ATTRIBUTE_KIND_VALUES["Dereferenceable"] || 0 }}
    DereferenceableOrNull           = {{ ATTRIBUTE_KIND_VALUES["DereferenceableOrNull"] || 0 }}
    DisableSanitizerInstrumentation = {{ ATTRIBUTE_KIND_VALUES["DisableSanitizerInstrumentation"] || 0 }}
    ElementType                     = {{ ATTRIBUTE_KIND_VALUES["ElementType"] || 0 }}
    Flatten                         = {{ ATTRIBUTE_KIND_VALUES["Flatten"] || 0 }}
    FnRetThunkExtern                = {{ ATTRIBUTE_KIND_VALUES["FnRetThunkExtern"] || 0 }}
    Hot                             = {{ ATTRIBUTE_KIND_VALUES["Hot"] || 0 }}
    HybridPatchable                 = {{ ATTRIBUTE_KIND_VALUES["HybridPatchable"] || 0 }}
    ImmArg                          = {{ ATTRIBUTE_KIND_VALUES["ImmArg"] || 0 }}
    InAlloca                        = {{ ATTRIBUTE_KIND_VALUES["InAlloca"] || 0 }}
    InReg                           = {{ ATTRIBUTE_KIND_VALUES["InReg"] || 0 }}
    InaccessibleMemOnly             = {{ ATTRIBUTE_KIND_VALUES["InaccessibleMemOnly"] || 0 }}
    InaccessibleMemOrArgMemOnly     = {{ ATTRIBUTE_KIND_VALUES["InaccessibleMemOrArgMemOnly"] || 0 }}
    Initializes                     = {{ ATTRIBUTE_KIND_VALUES["Initializes"] || 0 }}
    InlineHint                      = {{ ATTRIBUTE_KIND_VALUES["InlineHint"] || 0 }}
    JumpTable                       = {{ ATTRIBUTE_KIND_VALUES["JumpTable"] || 0 }}
    LikelyModuleLocal               = {{ ATTRIBUTE_KIND_VALUES["LikelyModuleLocal"] || 0 }}
    Memory                          = {{ ATTRIBUTE_KIND_VALUES["Memory"] || 0 }}
    MinSize                         = {{ ATTRIBUTE_KIND_VALUES["MinSize"] || 0 }}
    MustProgress                    = {{ ATTRIBUTE_KIND_VALUES["MustProgress"] || 0 }}
    Naked                           = {{ ATTRIBUTE_KIND_VALUES["Naked"] || 0 }}
    Nest                            = {{ ATTRIBUTE_KIND_VALUES["Nest"] || 0 }}
    NoAlias                         = {{ ATTRIBUTE_KIND_VALUES["NoAlias"] || 0 }}
    NoBuiltin                       = {{ ATTRIBUTE_KIND_VALUES["NoBuiltin"] || 0 }}
    NoCallback                      = {{ ATTRIBUTE_KIND_VALUES["NoCallback"] || 0 }}
    NoCapture                       = {{ ATTRIBUTE_KIND_VALUES["NoCapture"] || 0 }}
    NoCfCheck                       = {{ ATTRIBUTE_KIND_VALUES["NoCfCheck"] || 0 }}
    NoCreateUndefOrPoison           = {{ ATTRIBUTE_KIND_VALUES["NoCreateUndefOrPoison"] || 0 }}
    NoDivergenceSource              = {{ ATTRIBUTE_KIND_VALUES["NoDivergenceSource"] || 0 }}
    NoDuplicate                     = {{ ATTRIBUTE_KIND_VALUES["NoDuplicate"] || 0 }}
    NoExt                           = {{ ATTRIBUTE_KIND_VALUES["NoExt"] || 0 }}
    NoFPClass                       = {{ ATTRIBUTE_KIND_VALUES["NoFPClass"] || 0 }}
    NoFree                          = {{ ATTRIBUTE_KIND_VALUES["NoFree"] || 0 }}
    NoFreeObj                       = {{ ATTRIBUTE_KIND_VALUES["NoFreeObj"] || 0 }}
    NoIPA                           = {{ ATTRIBUTE_KIND_VALUES["NoIPA"] || 0 }}
    NoImplicitFloat                 = {{ ATTRIBUTE_KIND_VALUES["NoImplicitFloat"] || 0 }}
    NoInline                        = {{ ATTRIBUTE_KIND_VALUES["NoInline"] || 0 }}
    NoMerge                         = {{ ATTRIBUTE_KIND_VALUES["NoMerge"] || 0 }}
    NoOutline                       = {{ ATTRIBUTE_KIND_VALUES["NoOutline"] || 0 }}
    NoProfile                       = {{ ATTRIBUTE_KIND_VALUES["NoProfile"] || 0 }}
    NoRecurse                       = {{ ATTRIBUTE_KIND_VALUES["NoRecurse"] || 0 }}
    NoRedZone                       = {{ ATTRIBUTE_KIND_VALUES["NoRedZone"] || 0 }}
    NoReturn                        = {{ ATTRIBUTE_KIND_VALUES["NoReturn"] || 0 }}
    NoSanitizeBounds                = {{ ATTRIBUTE_KIND_VALUES["NoSanitizeBounds"] || 0 }}
    NoSanitizeCoverage              = {{ ATTRIBUTE_KIND_VALUES["NoSanitizeCoverage"] || 0 }}
    NoSync                          = {{ ATTRIBUTE_KIND_VALUES["NoSync"] || 0 }}
    NoUndef                         = {{ ATTRIBUTE_KIND_VALUES["NoUndef"] || 0 }}
    NoUnwind                        = {{ ATTRIBUTE_KIND_VALUES["NoUnwind"] || 0 }}
    NonLazyBind                     = {{ ATTRIBUTE_KIND_VALUES["NonLazyBind"] || 0 }}
    NonNull                         = {{ ATTRIBUTE_KIND_VALUES["NonNull"] || 0 }}
    NullPointerIsValid              = {{ ATTRIBUTE_KIND_VALUES["NullPointerIsValid"] || 0 }}
    OptForFuzzing                   = {{ ATTRIBUTE_KIND_VALUES["OptForFuzzing"] || 0 }}
    OptimizeForDebugging            = {{ ATTRIBUTE_KIND_VALUES["OptimizeForDebugging"] || 0 }}
    OptimizeForSize                 = {{ ATTRIBUTE_KIND_VALUES["OptimizeForSize"] || 0 }}
    OptimizeNone                    = {{ ATTRIBUTE_KIND_VALUES["OptimizeNone"] || 0 }}
    Preallocated                    = {{ ATTRIBUTE_KIND_VALUES["Preallocated"] || 0 }}
    PresplitCoroutine               = {{ ATTRIBUTE_KIND_VALUES["PresplitCoroutine"] || 0 }}
    Range                           = {{ ATTRIBUTE_KIND_VALUES["Range"] || 0 }}
    ReadNone                        = {{ ATTRIBUTE_KIND_VALUES["ReadNone"] || 0 }}
    ReadOnly                        = {{ ATTRIBUTE_KIND_VALUES["ReadOnly"] || 0 }}
    Returned                        = {{ ATTRIBUTE_KIND_VALUES["Returned"] || 0 }}
    ReturnsTwice                    = {{ ATTRIBUTE_KIND_VALUES["ReturnsTwice"] || 0 }}
    SExt                            = {{ ATTRIBUTE_KIND_VALUES["SExt"] || 0 }}
    SafeStack                       = {{ ATTRIBUTE_KIND_VALUES["SafeStack"] || 0 }}
    SanitizeAddress                 = {{ ATTRIBUTE_KIND_VALUES["SanitizeAddress"] || 0 }}
    SanitizeAllocToken              = {{ ATTRIBUTE_KIND_VALUES["SanitizeAllocToken"] || 0 }}
    SanitizeConcurrency             = {{ ATTRIBUTE_KIND_VALUES["SanitizeConcurrency"] || 0 }}
    SanitizeHWAddress               = {{ ATTRIBUTE_KIND_VALUES["SanitizeHWAddress"] || 0 }}
    SanitizeMemTag                  = {{ ATTRIBUTE_KIND_VALUES["SanitizeMemTag"] || 0 }}
    SanitizeMemory                  = {{ ATTRIBUTE_KIND_VALUES["SanitizeMemory"] || 0 }}
    SanitizeNumericalStability      = {{ ATTRIBUTE_KIND_VALUES["SanitizeNumericalStability"] || 0 }}
    SanitizeRealtime                = {{ ATTRIBUTE_KIND_VALUES["SanitizeRealtime"] || 0 }}
    SanitizeRealtimeBlocking        = {{ ATTRIBUTE_KIND_VALUES["SanitizeRealtimeBlocking"] || 0 }}
    SanitizeThread                  = {{ ATTRIBUTE_KIND_VALUES["SanitizeThread"] || 0 }}
    SanitizeType                    = {{ ATTRIBUTE_KIND_VALUES["SanitizeType"] || 0 }}
    ShadowCallStack                 = {{ ATTRIBUTE_KIND_VALUES["ShadowCallStack"] || 0 }}
    SkipProfile                     = {{ ATTRIBUTE_KIND_VALUES["SkipProfile"] || 0 }}
    Speculatable                    = {{ ATTRIBUTE_KIND_VALUES["Speculatable"] || 0 }}
    SpeculativeLoadHardening        = {{ ATTRIBUTE_KIND_VALUES["SpeculativeLoadHardening"] || 0 }}
    StackAlignment                  = {{ ATTRIBUTE_KIND_VALUES["StackAlignment"] || 0 }}
    StackProtect                    = {{ ATTRIBUTE_KIND_VALUES["StackProtect"] || 0 }}
    StackProtectReq                 = {{ ATTRIBUTE_KIND_VALUES["StackProtectReq"] || 0 }}
    StackProtectStrong              = {{ ATTRIBUTE_KIND_VALUES["StackProtectStrong"] || 0 }}
    StrictFP                        = {{ ATTRIBUTE_KIND_VALUES["StrictFP"] || 0 }}
    StructRet                       = {{ ATTRIBUTE_KIND_VALUES["StructRet"] || 0 }}
    SwiftAsync                      = {{ ATTRIBUTE_KIND_VALUES["SwiftAsync"] || 0 }}
    SwiftError                      = {{ ATTRIBUTE_KIND_VALUES["SwiftError"] || 0 }}
    SwiftSelf                       = {{ ATTRIBUTE_KIND_VALUES["SwiftSelf"] || 0 }}
    UWTable                         = {{ ATTRIBUTE_KIND_VALUES["UWTable"] || 0 }}
    VScaleRange                     = {{ ATTRIBUTE_KIND_VALUES["VScaleRange"] || 0 }}
    WillReturn                      = {{ ATTRIBUTE_KIND_VALUES["WillReturn"] || 0 }}
    Writable                        = {{ ATTRIBUTE_KIND_VALUES["Writable"] || 0 }}
    WriteOnly                       = {{ ATTRIBUTE_KIND_VALUES["WriteOnly"] || 0 }}
    ZExt                            = {{ ATTRIBUTE_KIND_VALUES["ZExt"] || 0 }}
  {% end %}

  def self.id_from_name(name : String) : UInt32
    LibLLVM.get_enum_attribute_kind_for_name(name, name.bytesize)
  end
end
