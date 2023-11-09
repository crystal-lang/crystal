#include <llvm/IR/DIBuilder.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/DebugLoc.h>
#include <llvm/Target/TargetMachine.h>

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

} // extern "C"
