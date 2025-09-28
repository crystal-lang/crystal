#include <llvm/Config/llvm-config.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/Target/TargetMachine.h>
#include <llvm/Target/TargetOptions.h>
#include <llvm/Target/CodeGenCWrappers.h>
#include <llvm-c/Target.h>
#include <llvm-c/TargetMachine.h>

using namespace llvm;

#define LLVM_VERSION_GE(major, minor) \
  (LLVM_VERSION_MAJOR > (major) || LLVM_VERSION_MAJOR == (major) && LLVM_VERSION_MINOR >= (minor))

#if !LLVM_VERSION_GE(9, 0)
#include <llvm/IR/DIBuilder.h>
#endif

#if LLVM_VERSION_GE(14, 0)
#include "llvm/MC/TargetRegistry.h"
#else
#include "llvm/Support/TargetRegistry.h"
#endif

#if LLVM_VERSION_GE(16, 0)
#define makeArrayRef ArrayRef
#endif

#if !LLVM_VERSION_GE(18, 0)
#define CodeGenOptLevel CodeGenOpt::Level
typedef struct LLVMOpaqueOperandBundle *LLVMOperandBundleRef;
DEFINE_SIMPLE_CONVERSION_FUNCTIONS(OperandBundleDef, LLVMOperandBundleRef)
#endif

// conversions taken from llvm/lib/Target/TargetMachineC.cpp
static TargetMachine *unwrap(LLVMTargetMachineRef P) {
  return reinterpret_cast<TargetMachine *>(P);
}
static Target *unwrap(LLVMTargetRef P) {
  return reinterpret_cast<Target*>(P);
}
static LLVMTargetMachineRef wrap(const TargetMachine *P) {
  return reinterpret_cast<LLVMTargetMachineRef>(const_cast<TargetMachine *>(P));
}
static LLVMTargetRef wrap(const Target * P) {
  return reinterpret_cast<LLVMTargetRef>(const_cast<Target*>(P));
}

extern "C" {

#if !LLVM_VERSION_GE(9, 0)
LLVMMetadataRef LLVMExtDIBuilderCreateEnumerator(LLVMDIBuilderRef Builder,
                                                 const char *Name, size_t NameLen,
                                                 int64_t Value,
                                                 LLVMBool IsUnsigned) {
  return wrap(unwrap(Builder)->createEnumerator({Name, NameLen}, Value,
                                                IsUnsigned != 0));
}

void LLVMExtClearCurrentDebugLocation(LLVMBuilderRef B) {
  unwrap(B)->SetCurrentDebugLocation(DebugLoc::get(0, 0, nullptr));
}
#endif

#if !LLVM_VERSION_GE(18, 0)
LLVMOperandBundleRef LLVMExtCreateOperandBundle(const char *Tag, size_t TagLen,
                                                LLVMValueRef *Args,
                                                unsigned NumArgs) {
  return wrap(new OperandBundleDef(std::string(Tag, TagLen),
                                   makeArrayRef(unwrap(Args), NumArgs)));
}

void LLVMExtDisposeOperandBundle(LLVMOperandBundleRef Bundle) {
  delete unwrap(Bundle);
}

LLVMValueRef
LLVMExtBuildCallWithOperandBundles(LLVMBuilderRef B, LLVMTypeRef Ty,
                                   LLVMValueRef Fn, LLVMValueRef *Args,
                                   unsigned NumArgs, LLVMOperandBundleRef *Bundles,
                                   unsigned NumBundles, const char *Name) {
  FunctionType *FTy = unwrap<FunctionType>(Ty);
  SmallVector<OperandBundleDef, 8> OBs;
  for (auto *Bundle : makeArrayRef(Bundles, NumBundles)) {
    OperandBundleDef *OB = unwrap(Bundle);
    OBs.push_back(*OB);
  }
  return wrap(unwrap(B)->CreateCall(
      FTy, unwrap(Fn), makeArrayRef(unwrap(Args), NumArgs), OBs, Name));
}

LLVMValueRef LLVMExtBuildInvokeWithOperandBundles(
    LLVMBuilderRef B, LLVMTypeRef Ty, LLVMValueRef Fn, LLVMValueRef *Args,
    unsigned NumArgs, LLVMBasicBlockRef Then, LLVMBasicBlockRef Catch,
    LLVMOperandBundleRef *Bundles, unsigned NumBundles, const char *Name) {
  SmallVector<OperandBundleDef, 8> OBs;
  for (auto *Bundle : makeArrayRef(Bundles, NumBundles)) {
    OperandBundleDef *OB = unwrap(Bundle);
    OBs.push_back(*OB);
  }
  return wrap(unwrap(B)->CreateInvoke(
      unwrap<FunctionType>(Ty), unwrap(Fn), unwrap(Then), unwrap(Catch),
      makeArrayRef(unwrap(Args), NumArgs), OBs, Name));
}
#endif

#if !LLVM_VERSION_GE(18, 0)
void LLVMExtSetTargetMachineGlobalISel(LLVMTargetMachineRef T, LLVMBool Enable) {
  unwrap(T)->setGlobalISel(Enable);
}
#endif

LLVMTargetMachineRef LLVMExtCreateTargetMachine(
    LLVMTargetRef T,
    const char *TripleStr,
    const char *CPU,
    const char *Features,
    LLVMCodeGenOptLevel Level,
    LLVMRelocMode Reloc,
    LLVMCodeModel CodeModel,
    int EmulatedTLS)
{
    // LLVMTargetMachineOptionsSetCodeGenOptLevel()
    CodeGenOptLevel OL;
    switch (Level) {
        case LLVMCodeGenLevelNone:
            OL = CodeGenOptLevel::None;
            break;
        case LLVMCodeGenLevelLess:
            OL = CodeGenOptLevel::Less;
            break;
        case LLVMCodeGenLevelAggressive:
            OL = CodeGenOptLevel::Aggressive;
            break;
        default:
            OL = CodeGenOptLevel::Default;
            break;
    }

    // LLVMTargetMachineOptionsSetRelocModel()
#if LLVM_VERSION_GE(16, 0)
    std::optional<Reloc::Model> RM;
#else
    Optional<Reloc::Model> RM;
#endif
    switch (Reloc){
        case LLVMRelocStatic:
            RM = Reloc::Static;
            break;
        case LLVMRelocPIC:
            RM = Reloc::PIC_;
            break;
        case LLVMRelocDynamicNoPic:
            RM = Reloc::DynamicNoPIC;
            break;
        case LLVMRelocROPI:
            RM = Reloc::ROPI;
            break;
        case LLVMRelocRWPI:
            RM = Reloc::RWPI;
            break;
        case LLVMRelocROPI_RWPI:
            RM = Reloc::ROPI_RWPI;
            break;
        case LLVMRelocDefault:
            break;
    }

    // LLVMTargetMachineOptionsSetCodeModel()
    bool JIT;
    auto CM = unwrap(CodeModel, JIT);

    TargetOptions TO;
    if (EmulatedTLS) {
        TO.EmulatedTLS = true;
    }
    return wrap(unwrap(T)->createTargetMachine(TripleStr, CPU, Features, TO, RM, CM, OL, JIT));
}

} // extern "C"
