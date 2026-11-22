{% skip_file unless LibLLVM::VERSION_MAJOR == 8 %}

module LLVM
  {%
    ATTRIBUTE_KIND_VALUES["Alignment"] = 1                    # EnumAttr
    ATTRIBUTE_KIND_VALUES["AllocSize"] = 2                    # EnumAttr
    ATTRIBUTE_KIND_VALUES["AlwaysInline"] = 3                 # EnumAttr
    ATTRIBUTE_KIND_VALUES["ArgMemOnly"] = 4                   # EnumAttr
    ATTRIBUTE_KIND_VALUES["Builtin"] = 5                      # EnumAttr
    ATTRIBUTE_KIND_VALUES["ByVal"] = 6                        # EnumAttr
    ATTRIBUTE_KIND_VALUES["Cold"] = 7                         # EnumAttr
    ATTRIBUTE_KIND_VALUES["Convergent"] = 8                   # EnumAttr
    ATTRIBUTE_KIND_VALUES["Dereferenceable"] = 9              # EnumAttr
    ATTRIBUTE_KIND_VALUES["DereferenceableOrNull"] = 10       # EnumAttr
    ATTRIBUTE_KIND_VALUES["InAlloca"] = 11                    # EnumAttr
    ATTRIBUTE_KIND_VALUES["InReg"] = 12                       # EnumAttr
    ATTRIBUTE_KIND_VALUES["InaccessibleMemOnly"] = 13         # EnumAttr
    ATTRIBUTE_KIND_VALUES["InaccessibleMemOrArgMemOnly"] = 14 # EnumAttr
    ATTRIBUTE_KIND_VALUES["InlineHint"] = 15                  # EnumAttr
    ATTRIBUTE_KIND_VALUES["JumpTable"] = 16                   # EnumAttr
    ATTRIBUTE_KIND_VALUES["MinSize"] = 17                     # EnumAttr
    ATTRIBUTE_KIND_VALUES["Naked"] = 18                       # EnumAttr
    ATTRIBUTE_KIND_VALUES["Nest"] = 19                        # EnumAttr
    ATTRIBUTE_KIND_VALUES["NoAlias"] = 20                     # EnumAttr
    ATTRIBUTE_KIND_VALUES["NoBuiltin"] = 21                   # EnumAttr
    ATTRIBUTE_KIND_VALUES["NoCapture"] = 22                   # EnumAttr
    ATTRIBUTE_KIND_VALUES["NoCfCheck"] = 23                   # EnumAttr
    ATTRIBUTE_KIND_VALUES["NoDuplicate"] = 24                 # EnumAttr
    ATTRIBUTE_KIND_VALUES["NoImplicitFloat"] = 25             # EnumAttr
    ATTRIBUTE_KIND_VALUES["NoInline"] = 26                    # EnumAttr
    ATTRIBUTE_KIND_VALUES["NoRecurse"] = 27                   # EnumAttr
    ATTRIBUTE_KIND_VALUES["NoRedZone"] = 28                   # EnumAttr
    ATTRIBUTE_KIND_VALUES["NoReturn"] = 29                    # EnumAttr
    ATTRIBUTE_KIND_VALUES["NoUnwind"] = 30                    # EnumAttr
    ATTRIBUTE_KIND_VALUES["NonLazyBind"] = 31                 # EnumAttr
    ATTRIBUTE_KIND_VALUES["NonNull"] = 32                     # EnumAttr
    ATTRIBUTE_KIND_VALUES["OptForFuzzing"] = 33               # EnumAttr
    ATTRIBUTE_KIND_VALUES["OptimizeForSize"] = 34             # EnumAttr
    ATTRIBUTE_KIND_VALUES["OptimizeNone"] = 35                # EnumAttr
    ATTRIBUTE_KIND_VALUES["ReadNone"] = 36                    # EnumAttr
    ATTRIBUTE_KIND_VALUES["ReadOnly"] = 37                    # EnumAttr
    ATTRIBUTE_KIND_VALUES["Returned"] = 38                    # EnumAttr
    ATTRIBUTE_KIND_VALUES["ReturnsTwice"] = 39                # EnumAttr
    ATTRIBUTE_KIND_VALUES["SExt"] = 40                        # EnumAttr
    ATTRIBUTE_KIND_VALUES["SafeStack"] = 41                   # EnumAttr
    ATTRIBUTE_KIND_VALUES["SanitizeAddress"] = 42             # EnumAttr
    ATTRIBUTE_KIND_VALUES["SanitizeHWAddress"] = 43           # EnumAttr
    ATTRIBUTE_KIND_VALUES["SanitizeMemory"] = 44              # EnumAttr
    ATTRIBUTE_KIND_VALUES["SanitizeThread"] = 45              # EnumAttr
    ATTRIBUTE_KIND_VALUES["ShadowCallStack"] = 46             # EnumAttr
    ATTRIBUTE_KIND_VALUES["Speculatable"] = 47                # EnumAttr
    ATTRIBUTE_KIND_VALUES["SpeculativeLoadHardening"] = 48    # EnumAttr
    ATTRIBUTE_KIND_VALUES["StackAlignment"] = 49              # EnumAttr
    ATTRIBUTE_KIND_VALUES["StackProtect"] = 50                # EnumAttr
    ATTRIBUTE_KIND_VALUES["StackProtectReq"] = 51             # EnumAttr
    ATTRIBUTE_KIND_VALUES["StackProtectStrong"] = 52          # EnumAttr
    ATTRIBUTE_KIND_VALUES["StrictFP"] = 53                    # EnumAttr
    ATTRIBUTE_KIND_VALUES["StructRet"] = 54                   # EnumAttr
    ATTRIBUTE_KIND_VALUES["SwiftError"] = 55                  # EnumAttr
    ATTRIBUTE_KIND_VALUES["SwiftSelf"] = 56                   # EnumAttr
    ATTRIBUTE_KIND_VALUES["UWTable"] = 57                     # EnumAttr
    ATTRIBUTE_KIND_VALUES["WriteOnly"] = 58                   # EnumAttr
    ATTRIBUTE_KIND_VALUES["ZExt"] = 59                        # EnumAttr
  %}
end
