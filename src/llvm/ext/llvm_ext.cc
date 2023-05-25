#include <llvm/IR/DIBuilder.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/DebugLoc.h>
#include <llvm/ExecutionEngine/ExecutionEngine.h>
#include <llvm/ExecutionEngine/RTDyldMemoryManager.h>

using namespace llvm;

#define LLVM_VERSION_GE(major, minor) \
  (LLVM_VERSION_MAJOR > (major) || LLVM_VERSION_MAJOR == (major) && LLVM_VERSION_MINOR >= (minor))

#define LLVM_VERSION_EQ(major, minor) \
  (LLVM_VERSION_MAJOR == (major) && LLVM_VERSION_MINOR == (minor))

#define LLVM_VERSION_LE(major, minor) \
  (LLVM_VERSION_MAJOR < (major) || LLVM_VERSION_MAJOR == (major) && LLVM_VERSION_MINOR <= (minor))

#include <llvm/Target/CodeGenCWrappers.h>

#if LLVM_VERSION_GE(16, 0)
#define makeArrayRef ArrayRef
#endif

typedef DIBuilder *DIBuilderRef;
#define DIArray DINodeArray
template <typename T> T *unwrapDIptr(LLVMMetadataRef v) {
  return (T *)(v ? unwrap<MDNode>(v) : NULL);
}

extern "C" {

#if LLVM_VERSION_GE(9, 0)
#else
LLVMMetadataRef LLVMExtDIBuilderCreateEnumerator(
    LLVMDIBuilderRef Dref, const char *Name, int64_t Value) {
  DIEnumerator *e = unwrap(Dref)->createEnumerator(Name, Value);
  return wrap(e);
}
#endif

void LLVMExtSetCurrentDebugLocation(
  LLVMBuilderRef Bref, unsigned Line, unsigned Col, LLVMMetadataRef Scope,
  LLVMMetadataRef InlinedAt) {
#if LLVM_VERSION_GE(12, 0)
  if (!Scope)
    unwrap(Bref)->SetCurrentDebugLocation(DebugLoc());
  else
    unwrap(Bref)->SetCurrentDebugLocation(
      DILocation::get(unwrap<MDNode>(Scope)->getContext(), Line, Col,
                      unwrapDIptr<DILocalScope>(Scope),
                      unwrapDIptr<DILocation>(InlinedAt)));
#else
  unwrap(Bref)->SetCurrentDebugLocation(
      DebugLoc::get(Line, Col, Scope ? unwrap<MDNode>(Scope) : nullptr,
                    InlinedAt ? unwrap<MDNode>(InlinedAt) : nullptr));
#endif
}

OperandBundleDef *LLVMExtBuildOperandBundleDef(
    const char *Name, LLVMValueRef *Inputs, unsigned NumInputs) {
  return new OperandBundleDef(Name, makeArrayRef(unwrap(Inputs), NumInputs));
}

LLVMValueRef LLVMExtBuildCall2(
    LLVMBuilderRef B, LLVMTypeRef Ty, LLVMValueRef Fn, LLVMValueRef *Args, unsigned NumArgs,
    OperandBundleDef *Bundle, const char *Name) {
  unsigned Len = Bundle ? 1 : 0;
  ArrayRef<OperandBundleDef> Bundles = makeArrayRef(Bundle, Len);
  return wrap(unwrap(B)->CreateCall(
       (llvm::FunctionType*) unwrap(Ty), unwrap(Fn), makeArrayRef(unwrap(Args), NumArgs), Bundles, Name));
}

LLVMValueRef LLVMExtBuildInvoke2(
    LLVMBuilderRef B,  LLVMTypeRef Ty, LLVMValueRef Fn, LLVMValueRef *Args, unsigned NumArgs,
    LLVMBasicBlockRef Then, LLVMBasicBlockRef Catch, OperandBundleDef *Bundle,
    const char *Name) {
  unsigned Len = Bundle ? 1 : 0;
  ArrayRef<OperandBundleDef> Bundles = makeArrayRef(Bundle, Len);
  return wrap(unwrap(B)->CreateInvoke((llvm::FunctionType*) unwrap(Ty), unwrap(Fn), unwrap(Then), unwrap(Catch),
                                      makeArrayRef(unwrap(Args), NumArgs),
                                      Bundles, Name));
}

static TargetMachine *unwrap(LLVMTargetMachineRef P) {
  return reinterpret_cast<TargetMachine *>(P);
}

void LLVMExtTargetMachineEnableGlobalIsel(LLVMTargetMachineRef T, LLVMBool Enable) {
  unwrap(T)->setGlobalISel(Enable);
}

// Copy paste of https://github.com/llvm/llvm-project/blob/dace8224f38a31636a02fe9c2af742222831f70c/llvm/lib/ExecutionEngine/ExecutionEngineBindings.cpp#L160-L214
// but with a parameter to set global isel state
LLVMBool LLVMExtCreateMCJITCompilerForModule(
    LLVMExecutionEngineRef *OutJIT, LLVMModuleRef M,
    LLVMMCJITCompilerOptions *PassedOptions, size_t SizeOfPassedOptions,
    LLVMBool EnableGlobalISel,
    char **OutError) {
  LLVMMCJITCompilerOptions options;
  // If the user passed a larger sized options struct, then they were compiled
  // against a newer LLVM. Tell them that something is wrong.
  if (SizeOfPassedOptions > sizeof(options)) {
    *OutError = strdup(
      "Refusing to use options struct that is larger than my own; assuming "
      "LLVM library mismatch.");
    return 1;
  }


  // Defend against the user having an old version of the API by ensuring that
  // any fields they didn't see are cleared. We must defend against fields being
  // set to the bitwise equivalent of zero, and assume that this means "do the
  // default" as if that option hadn't been available.
  LLVMInitializeMCJITCompilerOptions(&options, sizeof(options));
  memcpy(&options, PassedOptions, SizeOfPassedOptions);


  TargetOptions targetOptions;
  targetOptions.EnableFastISel = options.EnableFastISel;
  targetOptions.EnableGlobalISel = EnableGlobalISel;
  std::unique_ptr<Module> Mod(unwrap(M));

  if (Mod)
    // Set function attribute "frame-pointer" based on
    // NoFramePointerElim.
    for (auto &F : *Mod) {
      auto Attrs = F.getAttributes();
      StringRef Value = options.NoFramePointerElim ? "all" : "none";
      #if LLVM_VERSION_GE(14, 0)
        Attrs = Attrs.addFnAttribute(F.getContext(), "frame-pointer", Value);
      #else
        Attrs = Attrs.addAttribute(F.getContext(), AttributeList::FunctionIndex,
                                   "frame-pointer", Value);
      #endif
      F.setAttributes(Attrs);
    }


  std::string Error;
  EngineBuilder builder(std::move(Mod));
  builder.setEngineKind(EngineKind::JIT)
         .setErrorStr(&Error)
         .setOptLevel((CodeGenOpt::Level)options.OptLevel)
         .setTargetOptions(targetOptions);
  bool JIT;
  if (auto CM = unwrap(options.CodeModel, JIT))
    builder.setCodeModel(*CM);
  if (options.MCJMM)
    builder.setMCJITMemoryManager(
      std::unique_ptr<RTDyldMemoryManager>(unwrap(options.MCJMM)));

  TargetMachine* tm = builder.selectTarget();
  tm->setGlobalISel(EnableGlobalISel);

  if (ExecutionEngine *JIT = builder.create(tm)) {
    *OutJIT = wrap(JIT);
    return 0;
  }
  *OutError = strdup(Error.c_str());
  return 1;
}

} // extern "C"
