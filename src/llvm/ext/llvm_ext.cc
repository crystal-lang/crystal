#include "llvm/IR/DIBuilder.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/CBindingWrapping.h"
#include <llvm-c/Core.h>
#include <llvm/IR/DebugLoc.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Metadata.h>

using namespace llvm;

#define LLVM_VERSION_GE(major, minor) \
  (LLVM_VERSION_MAJOR > (major) || LLVM_VERSION_MAJOR == (major) && LLVM_VERSION_MINOR >= (minor))

#define LLVM_VERSION_EQ(major, minor) \
  (LLVM_VERSION_MAJOR == (major) && LLVM_VERSION_MINOR == (minor))

#define LLVM_VERSION_LE(major, minor) \
  (LLVM_VERSION_MAJOR < (major) || LLVM_VERSION_MAJOR == (major) && LLVM_VERSION_MINOR <= (minor))

#if LLVM_VERSION_LE(4, 0)
typedef struct LLVMOpaqueDIBuilder *LLVMDIBuilderRef;
DEFINE_SIMPLE_CONVERSION_FUNCTIONS(DIBuilder, LLVMDIBuilderRef)

typedef struct LLVMOpaqueMetadata *LLVMMetadataRef;
DEFINE_ISA_CONVERSION_FUNCTIONS(Metadata, LLVMMetadataRef)
inline Metadata **unwrap(LLVMMetadataRef *Vals) {
  return reinterpret_cast<Metadata **>(Vals);
}
#endif

typedef DIBuilder *DIBuilderRef;
#define DIArray DINodeArray
template <typename T> T *unwrapDIptr(LLVMMetadataRef v) {
  return (T *)(v ? unwrap<MDNode>(v) : NULL);
}

#if LLVM_VERSION_LE(3, 6)
#define OperandBundleDef void
#endif

#define DIDescriptor DIScope
#define unwrapDI unwrapDIptr

extern "C" {

LLVMDIBuilderRef LLVMNewDIBuilder(LLVMModuleRef mref) {
  Module *m = unwrap(mref);
  return wrap(new DIBuilder(*m));
}

void LLVMDIBuilderFinalize(LLVMDIBuilderRef dref) { unwrap(dref)->finalize(); }

LLVMMetadataRef LLVMDIBuilderCreateFile(DIBuilderRef Dref, const char *File,
                                        const char *Dir) {
  return wrap(Dref->createFile(File, Dir));
}

LLVMMetadataRef LLVMDIBuilderCreateCompileUnit(DIBuilderRef Dref, unsigned Lang,
                                               const char *File,
                                               const char *Dir,
                                               const char *Producer,
                                               int Optimized,
                                               const char *Flags,
                                               unsigned RuntimeVersion) {
#if LLVM_VERSION_LE(3, 9)
  return wrap(Dref->createCompileUnit(Lang, File, Dir, Producer, Optimized,
                                      Flags, RuntimeVersion));
#else
  DIFile *F = Dref->createFile(File, Dir);
  return wrap(Dref->createCompileUnit(Lang, F, Producer, Optimized,
                                      Flags, RuntimeVersion));
#endif
}

LLVMMetadataRef LLVMDIBuilderCreateFunction(
    DIBuilderRef Dref, LLVMMetadataRef Scope, const char *Name,
    const char *LinkageName, LLVMMetadataRef File, unsigned Line,
    LLVMMetadataRef CompositeType, bool IsLocalToUnit, bool IsDefinition,
    unsigned ScopeLine,
#if LLVM_VERSION_LE(3, 9)
    unsigned Flags,
#else
    DINode::DIFlags Flags,
#endif
    bool IsOptimized,
    LLVMValueRef Func) {
  DISubprogram *Sub = Dref->createFunction(
      unwrapDI<DIScope>(Scope), Name, LinkageName, unwrapDI<DIFile>(File), Line,
      unwrapDI<DISubroutineType>(CompositeType), IsLocalToUnit, IsDefinition,
      ScopeLine, Flags, IsOptimized);
  unwrap<Function>(Func)->setSubprogram(Sub);
  return wrap(Sub);
}

LLVMMetadataRef LLVMDIBuilderCreateLexicalBlock(DIBuilderRef Dref,
                                                LLVMMetadataRef Scope,
                                                LLVMMetadataRef File,
                                                unsigned Line,
                                                unsigned Column) {
  return wrap(Dref->createLexicalBlock(unwrapDI<DIDescriptor>(Scope),
                                       unwrapDI<DIFile>(File), Line, Column));
}

LLVMMetadataRef LLVMDIBuilderCreateBasicType(DIBuilderRef Dref,
                                             const char *Name,
                                             uint64_t SizeInBits,
                                             uint64_t AlignInBits,
                                             unsigned Encoding) {
#if LLVM_VERSION_LE(3, 9)
  return wrap(Dref->createBasicType(Name, SizeInBits, AlignInBits, Encoding));
#else
  return wrap(Dref->createBasicType(Name, SizeInBits, Encoding));
#endif
}

LLVMMetadataRef LLVMDIBuilderGetOrCreateTypeArray(DIBuilderRef Dref,
                                                  LLVMMetadataRef *Data,
                                                  unsigned Length) {
  Metadata **DataValue = unwrap(Data);
  return wrap(
      Dref->getOrCreateTypeArray(ArrayRef<Metadata *>(DataValue, Length))
          .get());
}

LLVMMetadataRef LLVMDIBuilderGetOrCreateArray(DIBuilderRef Dref,
                                              LLVMMetadataRef *Data,
                                              unsigned Length) {
  Metadata **DataValue = unwrap(Data);
  return wrap(
      Dref->getOrCreateArray(ArrayRef<Metadata *>(DataValue, Length)).get());
}

LLVMMetadataRef
LLVMDIBuilderCreateSubroutineType(DIBuilderRef Dref, LLVMMetadataRef File,
                                  LLVMMetadataRef ParameterTypes) {
  DISubroutineType *CT = Dref->createSubroutineType(DITypeRefArray(unwrap<MDTuple>(ParameterTypes)));
  return wrap(CT);
}

LLVMMetadataRef LLVMDIBuilderCreateAutoVariable(
    DIBuilderRef Dref, LLVMMetadataRef Scope, const char *Name,
    LLVMMetadataRef File, unsigned Line, LLVMMetadataRef Ty,
    int AlwaysPreserve,
#if LLVM_VERSION_LE(3, 9)
    unsigned Flags,
#else
    DINode::DIFlags Flags,
#endif
    uint32_t AlignInBits) {
#if LLVM_VERSION_LE(3, 9)
  DILocalVariable *V = Dref->createAutoVariable(
      unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), Line,
      unwrapDI<DIType>(Ty), AlwaysPreserve, Flags);
#else
  DILocalVariable *V = Dref->createAutoVariable(
      unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), Line,
      unwrapDI<DIType>(Ty), AlwaysPreserve, Flags, AlignInBits);
#endif
  return wrap(V);
}

LLVMMetadataRef LLVMDIBuilderCreateParameterVariable(
    DIBuilderRef Dref, LLVMMetadataRef Scope, const char *Name,
    unsigned ArgNo, LLVMMetadataRef File, unsigned Line,
    LLVMMetadataRef Ty, int AlwaysPreserve,
#if LLVM_VERSION_LE(3, 9)
    unsigned Flags
#else
    DINode::DIFlags Flags
#endif
    ) {
  DILocalVariable *V = Dref->createParameterVariable
    (unwrapDI<DIDescriptor>(Scope), Name, ArgNo, unwrapDI<DIFile>(File), Line,
     unwrapDI<DIType>(Ty), AlwaysPreserve, Flags);
  return wrap(V);
}

LLVMValueRef LLVMDIBuilderInsertDeclareAtEnd(DIBuilderRef Dref,
                                             LLVMValueRef Storage,
                                             LLVMMetadataRef VarInfo,
                                             LLVMMetadataRef Expr,
                                             LLVMValueRef DL,
                                             LLVMBasicBlockRef Block) {
  Instruction *Instr =
    Dref->insertDeclare(unwrap(Storage), unwrap<DILocalVariable>(VarInfo),
                        unwrapDI<DIExpression>(Expr),
                        DebugLoc(cast<MDNode>(unwrap<MetadataAsValue>(DL)->getMetadata())),
                        unwrap(Block));
  return wrap(Instr);
}

LLVMMetadataRef LLVMDIBuilderCreateExpression(DIBuilderRef Dref, int64_t *Addr,
                                              size_t Length) {
  return wrap(Dref->createExpression(ArrayRef<int64_t>(Addr, Length)));
}

LLVMMetadataRef LLVMDIBuilderCreateEnumerationType(
    DIBuilderRef Dref, LLVMMetadataRef Scope, const char *Name,
    LLVMMetadataRef File, unsigned LineNumber, uint64_t SizeInBits,
    uint64_t AlignInBits, LLVMMetadataRef Elements,
    LLVMMetadataRef UnderlyingType) {
  DICompositeType *enumType = Dref->createEnumerationType(
      unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), LineNumber,
      SizeInBits, AlignInBits, DINodeArray(unwrapDI<MDTuple>(Elements)),
      unwrapDI<DIType>(UnderlyingType));
  return wrap(enumType);
}

LLVMMetadataRef LLVMDIBuilderCreateEnumerator(DIBuilderRef Dref,
                                              const char *Name, int64_t Value) {
  DIEnumerator *e = Dref->createEnumerator(Name, Value);
  return wrap(e);
}

LLVMMetadataRef
LLVMDIBuilderCreateStructType(DIBuilderRef Dref,
                              LLVMMetadataRef Scope,
                              const char *Name,
                              LLVMMetadataRef File,
                              unsigned Line,
                              uint64_t SizeInBits,
                              uint64_t AlignInBits,
#if LLVM_VERSION_LE(3, 9)
                              unsigned Flags,
#else
                              DINode::DIFlags Flags,
#endif
                              LLVMMetadataRef DerivedFrom,
                              LLVMMetadataRef Elements) {
  DICompositeType *CT = Dref->createStructType(
      unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), Line,
      SizeInBits, AlignInBits, Flags, unwrapDI<DIType>(DerivedFrom),
      DINodeArray(unwrapDI<MDTuple>(Elements)));
  return wrap(CT);
}

LLVMMetadataRef
LLVMDIBuilderCreateReplaceableCompositeType(DIBuilderRef Dref,
                                            LLVMMetadataRef Scope,
                                            const char *Name,
                                            LLVMMetadataRef File,
                                            unsigned Line)
{
  DICompositeType *CT = Dref->createReplaceableCompositeType(llvm::dwarf::DW_TAG_structure_type,
                                                             Name,
                                                             unwrapDI<DIScope>(Scope),
                                                             unwrapDI<DIFile>(File),
                                                             Line);
  return wrap(CT);
}

void
LLVMDIBuilderReplaceTemporary(DIBuilderRef Dref,
                              LLVMMetadataRef From,
                              LLVMMetadataRef To)
{
  auto *Node = unwrap<MDNode>(From);
  auto *Type = unwrap<DIType>(To);

  llvm::TempMDNode fwd_decl(Node);
  Dref->replaceTemporary(std::move(fwd_decl), Type);
}

LLVMMetadataRef
LLVMDIBuilderCreateMemberType(DIBuilderRef Dref, LLVMMetadataRef Scope,
                              const char *Name, LLVMMetadataRef File,
                              unsigned Line, uint64_t SizeInBits,
                              uint64_t AlignInBits, uint64_t OffsetInBits,
#if LLVM_VERSION_LE(3, 9)
                              unsigned Flags,
#else
                              DINode::DIFlags Flags,
#endif
                              LLVMMetadataRef Ty) {
  DIDerivedType *DT = Dref->createMemberType(
      unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), Line,
      SizeInBits, AlignInBits, OffsetInBits, Flags, unwrapDI<DIType>(Ty));
  return wrap(DT);
}

LLVMMetadataRef LLVMDIBuilderCreatePointerType(DIBuilderRef Dref,
                                               LLVMMetadataRef PointeeType,
                                               uint64_t SizeInBits,
                                               uint64_t AlignInBits,
                                               const char *Name) {
  DIDerivedType *T = Dref->createPointerType(unwrapDI<DIType>(PointeeType),
                                             SizeInBits, AlignInBits,
#if LLVM_VERSION_GE(5, 0)
                                             None,
#endif
                                             Name);
  return wrap(T);
}

LLVMMetadataRef LLVMTemporaryMDNode(LLVMContextRef C, LLVMMetadataRef *MDs,
                                    unsigned Count) {
  return wrap(MDTuple::getTemporary(*unwrap(C),
                                    ArrayRef<Metadata *>(unwrap(MDs), Count))
                  .release());
}

void LLVMMetadataReplaceAllUsesWith(LLVMMetadataRef MD, LLVMMetadataRef New) {
  auto *Node = unwrap<MDNode>(MD);
  Node->replaceAllUsesWith(unwrap<MDNode>(New));
  MDNode::deleteTemporary(Node);
}

void LLVMSetCurrentDebugLocation2(LLVMBuilderRef Bref, unsigned Line,
                                  unsigned Col, LLVMMetadataRef Scope,
                                  LLVMMetadataRef InlinedAt) {
  unwrap(Bref)->SetCurrentDebugLocation(
      DebugLoc::get(Line, Col, Scope ? unwrap<MDNode>(Scope) : nullptr,
                    InlinedAt ? unwrap<MDNode>(InlinedAt) : nullptr));
}

LLVMValueRef LLVMExtBuildCmpxchg(LLVMBuilderRef B,
                               LLVMValueRef PTR, LLVMValueRef Cmp, LLVMValueRef New,
                               LLVMAtomicOrdering SuccessOrdering,
                               LLVMAtomicOrdering FailureOrdering) {
  return wrap(unwrap(B)->CreateAtomicCmpXchg(unwrap(PTR), unwrap(Cmp), unwrap(New),
    (llvm::AtomicOrdering)SuccessOrdering, (llvm::AtomicOrdering)FailureOrdering));
}

void LLVMExtSetOrdering(LLVMValueRef MemAccessInst, LLVMAtomicOrdering Ordering) {
  Value *P = unwrap<Value>(MemAccessInst);
  AtomicOrdering O = (AtomicOrdering) Ordering;

  if (LoadInst *LI = dyn_cast<LoadInst>(P))
    return LI->setOrdering(O);
  return cast<StoreInst>(P)->setOrdering(O);
}

LLVMValueRef LLVMExtBuildCatchPad(LLVMBuilderRef B, LLVMValueRef ParentPad,
                                  unsigned ArgCount, LLVMValueRef *LLArgs, const char *Name) {
#if LLVM_VERSION_GE(3, 8)
  Value **Args = unwrap(LLArgs);
  return wrap(unwrap(B)->CreateCatchPad(
      unwrap(ParentPad), ArrayRef<Value *>(Args, ArgCount), Name));
#else
  return nullptr;
#endif
}

LLVMValueRef LLVMExtBuildCatchRet(LLVMBuilderRef B,
                                  LLVMValueRef Pad,
                                  LLVMBasicBlockRef BB) {
#if LLVM_VERSION_GE(3, 8)
  return wrap(unwrap(B)->CreateCatchRet(cast<CatchPadInst>(unwrap(Pad)),
                                              unwrap(BB)));
#else
  return nullptr;
#endif
}

LLVMValueRef LLVMExtBuildCatchSwitch(LLVMBuilderRef B,
                                     LLVMValueRef ParentPad,
                                     LLVMBasicBlockRef BB,
                                     unsigned NumHandlers,
                                     const char *Name) {
#if LLVM_VERSION_GE(3, 8)
  if (ParentPad == nullptr) {
    Type *Ty = Type::getTokenTy(unwrap(B)->getContext());
    ParentPad = wrap(Constant::getNullValue(Ty));
  }
  return wrap(unwrap(B)->CreateCatchSwitch(unwrap(ParentPad), unwrap(BB),
                                                 NumHandlers, Name));
#else
  return nullptr;
#endif
}

void LLVMExtAddHandler(LLVMValueRef CatchSwitchRef,
                       LLVMBasicBlockRef Handler) {
#if LLVM_VERSION_GE(3, 8)
  Value *CatchSwitch = unwrap(CatchSwitchRef);
  cast<CatchSwitchInst>(CatchSwitch)->addHandler(unwrap(Handler));
#endif
}

OperandBundleDef *LLVMExtBuildOperandBundleDef(const char *Name,
                                                           LLVMValueRef *Inputs,
                                                           unsigned NumInputs) {
#if LLVM_VERSION_GE(3, 8)
  return new OperandBundleDef(Name, makeArrayRef(unwrap(Inputs), NumInputs));
#else
  return nullptr;
#endif
}

LLVMValueRef LLVMExtBuildCall(LLVMBuilderRef B, LLVMValueRef Fn,
                                          LLVMValueRef *Args, unsigned NumArgs,
                                          OperandBundleDef *Bundle,
                                          const char *Name) {
#if LLVM_VERSION_GE(3, 8)
  unsigned Len = Bundle ? 1 : 0;
  ArrayRef<OperandBundleDef> Bundles = makeArrayRef(Bundle, Len);
  return wrap(unwrap(B)->CreateCall(
      unwrap(Fn), makeArrayRef(unwrap(Args), NumArgs), Bundles, Name));
#else
  return LLVMBuildCall(B, Fn, Args, NumArgs, Name);
#endif
}

LLVMValueRef LLVMExtBuildInvoke(LLVMBuilderRef B, LLVMValueRef Fn, LLVMValueRef *Args,
                    unsigned NumArgs, LLVMBasicBlockRef Then,
                    LLVMBasicBlockRef Catch, OperandBundleDef *Bundle,
                    const char *Name) {
#if LLVM_VERSION_GE(3, 8)
  unsigned Len = Bundle ? 1 : 0;
  ArrayRef<OperandBundleDef> Bundles = makeArrayRef(Bundle, Len);
  return wrap(unwrap(B)->CreateInvoke(unwrap(Fn), unwrap(Then), unwrap(Catch),
                                      makeArrayRef(unwrap(Args), NumArgs),
                                      Bundles, Name));
#else
  return LLVMBuildInvoke(B, Fn, Args, NumArgs, Then, Catch, Name);
#endif
}

}
