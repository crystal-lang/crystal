#include "llvm/IR/DIBuilder.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/CBindingWrapping.h"
#include <llvm-c/Core.h>
#include <llvm/IR/DebugLoc.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Metadata.h>

using namespace llvm;

#if LLVM_VERSION_MAJOR == 3 && LLVM_VERSION_MINOR == 5
#define HAVE_LLVM_35 1
#endif

#if LLVM_VERSION_MAJOR == 3 && LLVM_VERSION_MINOR <= 6
#define HAVE_LLVM_36_OR_LOWER 1
#endif

#if LLVM_VERSION_MAJOR == 3 && LLVM_VERSION_MINOR == 8
#define HAVE_LLVM_38 1
#endif

typedef struct LLVMOpaqueDIBuilder *LLVMDIBuilderRef;
DEFINE_SIMPLE_CONVERSION_FUNCTIONS(DIBuilder, LLVMDIBuilderRef)

#if HAVE_LLVM_35
typedef LLVMValueRef LLVMMetadataRef;
typedef Value Metadata;
#define DIBuilderRef LLVMDIBuilderRef
#else
typedef struct LLVMOpaqueMetadata *LLVMMetadataRef;
DEFINE_ISA_CONVERSION_FUNCTIONS(Metadata, LLVMMetadataRef)

inline Metadata **unwrap(LLVMMetadataRef *Vals) {
  return reinterpret_cast<Metadata **>(Vals);
}
#endif

#if HAVE_LLVM_36_OR_LOWER
template <typename T> T unwrapDIptr(LLVMMetadataRef v) {
  return v ? T(unwrap<MDNode>(v)) : T();
}
#define DIBuilderRef LLVMDIBuilderRef
#else
typedef DIBuilder *DIBuilderRef;
#define DIArray DINodeArray

template <typename T> T *unwrapDIptr(LLVMMetadataRef v) {
  return (T *)(v ? unwrap<MDNode>(v) : NULL);
}
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
#if HAVE_LLVM_36_OR_LOWER
  DIBuilder *D = unwrap(Dref);
  DIFile F = D->createFile(File, Dir);
  return wrap(F);
#else
  return wrap(Dref->createFile(File, Dir));
#endif
}

LLVMMetadataRef LLVMDIBuilderCreateCompileUnit(DIBuilderRef Dref, unsigned Lang,
                                               const char *File,
                                               const char *Dir,
                                               const char *Producer,
                                               int Optimized, const char *Flags,
                                               unsigned RuntimeVersion) {
#if HAVE_LLVM_36_OR_LOWER
  DIBuilder *D = unwrap(Dref);
  DICompileUnit CU = D->createCompileUnit(Lang, File, Dir, Producer, Optimized,
                                          Flags, RuntimeVersion);
  return wrap(CU);
#else
  return wrap(Dref->createCompileUnit(Lang, File, Dir, Producer, Optimized,
                                      Flags, RuntimeVersion));
#endif
}

LLVMMetadataRef LLVMDIBuilderCreateFunction(
    DIBuilderRef Dref, LLVMMetadataRef Scope, const char *Name,
    const char *LinkageName, LLVMMetadataRef File, unsigned Line,
    LLVMMetadataRef CompositeType, bool IsLocalToUnit, bool IsDefinition,
    unsigned ScopeLine, unsigned Flags, bool IsOptimized, LLVMValueRef Func) {
#if HAVE_LLVM_36_OR_LOWER
  DIBuilder *D = unwrap(Dref);
  DISubprogram Sub = D->createFunction(
      unwrapDI<DIDescriptor>(Scope), Name, LinkageName, unwrapDI<DIFile>(File),
      Line, unwrapDI<DICompositeType>(CompositeType), IsLocalToUnit,
      IsDefinition, ScopeLine, Flags, IsOptimized, unwrap<Function>(Func));
#else
  DISubprogram *Sub = Dref->createFunction(
      unwrapDI<DIScope>(Scope), Name, LinkageName, unwrapDI<DIFile>(File), Line,
      unwrapDI<DISubroutineType>(CompositeType), IsLocalToUnit, IsDefinition,
      ScopeLine, Flags, IsOptimized);
  unwrap<Function>(Func)->setSubprogram(Sub);
#endif
  return wrap(Sub);
}

LLVMMetadataRef LLVMDIBuilderCreateLexicalBlock(DIBuilderRef Dref,
                                                LLVMMetadataRef Scope,
                                                LLVMMetadataRef File,
                                                unsigned Line,
                                                unsigned Column) {
#if HAVE_LLVM_36_OR_LOWER
  DIBuilder *D = unwrap(Dref);
  DILexicalBlock LB = D->createLexicalBlock(
#if HAVE_LLVM_35
      unwrapDI<DIDescriptor>(Scope), unwrapDI<DIFile>(File), Line, Column, 0);
#else
      unwrapDI<DIDescriptor>(Scope), unwrapDI<DIFile>(File), Line, Column);
#endif
  return wrap(LB);
#else
  return wrap(Dref->createLexicalBlock(unwrapDI<DIDescriptor>(Scope),
                                       unwrapDI<DIFile>(File), Line, Column));
#endif
}

LLVMMetadataRef LLVMDIBuilderCreateBasicType(DIBuilderRef Dref,
                                             const char *Name,
                                             uint64_t SizeInBits,
                                             uint64_t AlignInBits,
                                             unsigned Encoding) {
#if HAVE_LLVM_36_OR_LOWER
  DIBuilder *D = unwrap(Dref);
  DIBasicType T = D->createBasicType(Name, SizeInBits, AlignInBits, Encoding);
  return wrap(T);
#else
  return wrap(Dref->createBasicType(Name, SizeInBits, AlignInBits, Encoding));
#endif
}

LLVMMetadataRef LLVMDIBuilderGetOrCreateTypeArray(DIBuilderRef Dref,
                                                  LLVMMetadataRef *Data,
                                                  unsigned Length) {
#if HAVE_LLVM_36_OR_LOWER
  DIBuilder *D = unwrap(Dref);
#if HAVE_LLVM_35
  Value **DataValue = unwrap(Data);
  ArrayRef<Value *> Elements(DataValue, Length);
  DIArray A = D->getOrCreateArray(Elements);
#else
  Metadata **DataValue = unwrap(Data);
  ArrayRef<Metadata *> Elements(DataValue, Length);
  DITypeArray A = D->getOrCreateTypeArray(Elements);
#endif
  return wrap(A);
#else
  Metadata **DataValue = unwrap(Data);
  return wrap(
      Dref->getOrCreateTypeArray(ArrayRef<Metadata *>(DataValue, Length))
          .get());
#endif
}

LLVMMetadataRef LLVMDIBuilderGetOrCreateArray(DIBuilderRef Dref,
                                              LLVMMetadataRef *Data,
                                              unsigned Length) {
#if HAVE_LLVM_36_OR_LOWER
  DIBuilder *D = unwrap(Dref);
  ArrayRef<Metadata *> elements(unwrap(Data), Length);
  DIArray a = D->getOrCreateArray(elements);

  return wrap(a);
#else
  Metadata **DataValue = unwrap(Data);
  return wrap(
      Dref->getOrCreateArray(ArrayRef<Metadata *>(DataValue, Length)).get());
#endif
}

LLVMMetadataRef
LLVMDIBuilderCreateSubroutineType(DIBuilderRef Dref, LLVMMetadataRef File,
                                  LLVMMetadataRef ParameterTypes) {
#if HAVE_LLVM_36_OR_LOWER
  DIBuilder *D = unwrap(Dref);
  DICompositeType CT = D->createSubroutineType(
#if HAVE_LLVM_35
      unwrapDI<DIFile>(File), unwrapDI<DIArray>(ParameterTypes));
#else
      unwrapDI<DIFile>(File), unwrapDI<DITypeArray>(ParameterTypes));
#endif
#else
  DISubroutineType *CT = Dref->createSubroutineType(
      DITypeRefArray(unwrap<MDTuple>(ParameterTypes)));
#endif
  return wrap(CT);
}

LLVMMetadataRef LLVMDIBuilderCreateLocalVariable(
    DIBuilderRef Dref, unsigned Tag, LLVMMetadataRef Scope, const char *Name,
    LLVMMetadataRef File, unsigned Line, LLVMMetadataRef Ty, int AlwaysPreserve,
    unsigned Flags, unsigned ArgNo) {
#if HAVE_LLVM_36_OR_LOWER
  DIBuilder *D = unwrap(Dref);
  DIVariable V = D->createLocalVariable(
      Tag, unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), Line,
      unwrapDI<DIType>(Ty), AlwaysPreserve, Flags, ArgNo);
  return wrap(V);
#else
  if (Tag == 0x100) { // DW_TAG_auto_variable
    DILocalVariable *V = Dref->createAutoVariable(
        unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), Line,
        unwrapDI<DIType>(Ty), AlwaysPreserve, Flags);
    return wrap(V);
  } else {
    DILocalVariable *V = Dref->createParameterVariable(
        unwrapDI<DIDescriptor>(Scope), Name, ArgNo, unwrapDI<DIFile>(File),
        Line, unwrapDI<DIType>(Ty), AlwaysPreserve, Flags);
    return wrap(V);
  }
#endif
}

#if HAVE_LLVM_36_OR_LOWER
LLVMValueRef LLVMDIBuilderInsertDeclareAtEnd(LLVMDIBuilderRef Dref,
                                             LLVMValueRef Storage,
                                             LLVMMetadataRef VarInfo,
                                             LLVMMetadataRef Expr,
                                             LLVMBasicBlockRef Block) {
  DIBuilder *D = unwrap(Dref);
  Instruction *Instr =
      D->insertDeclare(unwrap(Storage), unwrapDI<DIVariable>(VarInfo),
#if HAVE_LLVM_35
#else
                       unwrapDI<DIExpression>(Expr),
#endif
                       unwrap(Block));
#else
LLVMValueRef
LLVMDIBuilderInsertDeclareAtEnd(DIBuilderRef Dref, LLVMValueRef Storage,
                                LLVMMetadataRef VarInfo, LLVMMetadataRef Expr,
                                LLVMValueRef DL, LLVMBasicBlockRef Block) {
  Instruction *Instr = Dref->insertDeclare(
      unwrap(Storage), unwrap<DILocalVariable>(VarInfo),
      unwrapDI<DIExpression>(Expr),
      DebugLoc(cast<MDNode>(unwrap<MetadataAsValue>(DL)->getMetadata())),
      unwrap(Block));
#endif
  return wrap(Instr);
}

LLVMMetadataRef LLVMDIBuilderCreateExpression(DIBuilderRef Dref, int64_t *Addr,
                                              size_t Length) {
#if HAVE_LLVM_36_OR_LOWER
#if HAVE_LLVM_35
  return nullptr;
#else
  DIBuilder *D = unwrap(Dref);
  DIExpression Expr = D->createExpression(ArrayRef<int64_t>(Addr, Length));
  return wrap(Expr);
#endif
#else
  return wrap(Dref->createExpression(ArrayRef<int64_t>(Addr, Length)));
#endif
}

LLVMMetadataRef LLVMDIBuilderCreateEnumerationType(
    DIBuilderRef Dref, LLVMMetadataRef Scope, const char *Name,
    LLVMMetadataRef File, unsigned LineNumber, uint64_t SizeInBits,
    uint64_t AlignInBits, LLVMMetadataRef Elements,
    LLVMMetadataRef UnderlyingType) {
#if HAVE_LLVM_36_OR_LOWER
  DIBuilder *D = unwrap(Dref);
  DICompositeType enumType = D->createEnumerationType(
      unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), LineNumber,
      SizeInBits, AlignInBits, unwrapDI<DIArray>(Elements),
      unwrapDI<DIType>(UnderlyingType));
#else
  DICompositeType *enumType = Dref->createEnumerationType(
      unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), LineNumber,
      SizeInBits, AlignInBits, DINodeArray(unwrapDI<MDTuple>(Elements)),
      unwrapDI<DIType>(UnderlyingType));
#endif
  return wrap(enumType);
}

LLVMMetadataRef LLVMDIBuilderCreateEnumerator(DIBuilderRef Dref,
                                              const char *Name, int64_t Value) {
#if HAVE_LLVM_36_OR_LOWER
  DIBuilder *D = unwrap(Dref);
  DIEnumerator e = D->createEnumerator(Name, Value);
  return wrap(e);
#else
  DIEnumerator *e = Dref->createEnumerator(Name, Value);
#endif
  return wrap(e);
}

LLVMMetadataRef LLVMDIBuilderCreateStructType(
    DIBuilderRef Dref, LLVMMetadataRef Scope, const char *Name,
    LLVMMetadataRef File, unsigned Line, uint64_t SizeInBits,
    uint64_t AlignInBits, unsigned Flags, LLVMMetadataRef DerivedFrom,
    LLVMMetadataRef Elements) {
#if HAVE_LLVM_36_OR_LOWER
  DIBuilder *D = unwrap(Dref);
  DICompositeType CT = D->createStructType(
      unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), Line,
      SizeInBits, AlignInBits, Flags, unwrapDI<DIType>(DerivedFrom),
      unwrapDI<DIArray>(Elements));
#else
  DICompositeType *CT = Dref->createStructType(
      unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), Line,
      SizeInBits, AlignInBits, Flags, unwrapDI<DIType>(DerivedFrom),
      DINodeArray(unwrapDI<MDTuple>(Elements)));
#endif
  return wrap(CT);
}

LLVMMetadataRef
LLVMDIBuilderCreateMemberType(DIBuilderRef Dref, LLVMMetadataRef Scope,
                              const char *Name, LLVMMetadataRef File,
                              unsigned Line, uint64_t SizeInBits,
                              uint64_t AlignInBits, uint64_t OffsetInBits,
                              unsigned Flags, LLVMMetadataRef Ty) {
#if HAVE_LLVM_36_OR_LOWER
  DIBuilder *D = unwrap(Dref);
  DIDerivedType DT = D->createMemberType(
      unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), Line,
      SizeInBits, AlignInBits, OffsetInBits, Flags, unwrapDI<DIType>(Ty));
#else
  DIDerivedType *DT = Dref->createMemberType(
      unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), Line,
      SizeInBits, AlignInBits, OffsetInBits, Flags, unwrapDI<DIType>(Ty));
#endif
  return wrap(DT);
}

LLVMMetadataRef LLVMDIBuilderCreatePointerType(DIBuilderRef Dref,
                                               LLVMMetadataRef PointeeType,
                                               uint64_t SizeInBits,
                                               uint64_t AlignInBits,
                                               const char *Name) {
#if HAVE_LLVM_36_OR_LOWER
  DIBuilder *D = unwrap(Dref);
  DIDerivedType T = D->createPointerType(unwrapDI<DIType>(PointeeType),
                                         SizeInBits, AlignInBits, Name);
#else
  DIDerivedType *T = Dref->createPointerType(unwrapDI<DIType>(PointeeType),
                                             SizeInBits, AlignInBits, Name);
#endif
  return wrap(T);
}

LLVMMetadataRef LLVMTemporaryMDNode(LLVMContextRef C, LLVMMetadataRef *MDs,
                                    unsigned Count) {
#if HAVE_LLVM_36_OR_LOWER
  return wrap(MDNode::getTemporary(*unwrap(C),
                                   ArrayRef<Metadata *>(unwrap(MDs), Count)));
#else
  return wrap(MDTuple::getTemporary(*unwrap(C),
                                    ArrayRef<Metadata *>(unwrap(MDs), Count))
                  .release());
#endif
}

void LLVMMetadataReplaceAllUsesWith(LLVMMetadataRef MD, LLVMMetadataRef New) {
#if HAVE_LLVM_36_OR_LOWER
#if HAVE_LLVM_35
  auto *Node = unwrap<MDNode>(MD);
#else
  auto *Node = unwrap<MDNodeFwdDecl>(MD);
#endif
#else
  auto *Node = unwrap<MDNode>(MD);
#endif
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
}
