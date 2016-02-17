#include <llvm-c/Core.h>
#include <llvm/IR/DebugLoc.h>
#include <llvm/IR/Metadata.h>
#include "llvm/Support/CBindingWrapping.h"
#include <llvm/IR/LLVMContext.h>
#include "llvm/IR/Module.h"
#include "llvm/IR/DIBuilder.h"
#include "llvm/IR/IRBuilder.h"

using namespace llvm;

#if LLVM_VERSION_MAJOR == 3 && LLVM_VERSION_MINOR == 5
  #define HAVE_LLVM_35 1
#endif


typedef struct LLVMOpaqueDIBuilder *LLVMDIBuilderRef;
DEFINE_SIMPLE_CONVERSION_FUNCTIONS(DIBuilder, LLVMDIBuilderRef)

#if HAVE_LLVM_35
typedef LLVMValueRef LLVMMetadataRef;
typedef Value Metadata;
#else
typedef struct LLVMOpaqueMetadata *LLVMMetadataRef;
DEFINE_ISA_CONVERSION_FUNCTIONS(Metadata, LLVMMetadataRef)

inline Metadata **unwrap(LLVMMetadataRef *Vals) {
  return reinterpret_cast<Metadata**>(Vals);
}
#endif

template <typename T> T unwrapDI(LLVMMetadataRef v) {
  return v ? T(unwrap<MDNode>(v)) : T();
}

extern "C" {

LLVMDIBuilderRef LLVMNewDIBuilder(LLVMModuleRef mref) {
  Module *m = unwrap(mref);
  return wrap(new DIBuilder(*m));
}

void LLVMDIBuilderFinalize(LLVMDIBuilderRef dref) { unwrap(dref)->finalize(); }

LLVMMetadataRef LLVMDIBuilderCreateFile(LLVMDIBuilderRef Dref, const char *File, const char *Dir) {
  DIBuilder *D = unwrap(Dref);
  DIFile F = D->createFile(File, Dir);
  return wrap(F);
}

LLVMMetadataRef LLVMDIBuilderCreateCompileUnit(LLVMDIBuilderRef Dref,
                                               unsigned Lang, const char *File,
                                               const char *Dir,
                                               const char *Producer,
                                               int Optimized, const char *Flags,
                                               unsigned RuntimeVersion) {
  DIBuilder *D = unwrap(Dref);
  DICompileUnit CU = D->createCompileUnit(Lang, File, Dir, Producer, Optimized,
                                          Flags, RuntimeVersion);
  return wrap(CU);
}


LLVMMetadataRef LLVMDIBuilderCreateFunction(
    LLVMDIBuilderRef Dref, LLVMMetadataRef Scope, const char *Name,
    const char *LinkageName, LLVMMetadataRef File, unsigned Line,
    LLVMMetadataRef CompositeType, int IsLocalToUnit, int IsDefinition,
    unsigned ScopeLine, unsigned Flags, int IsOptimized, LLVMValueRef Func) {
  DIBuilder *D = unwrap(Dref);
  DISubprogram SP = D->createFunction(
      unwrapDI<DIDescriptor>(Scope), Name, LinkageName, unwrapDI<DIFile>(File),
      Line, unwrapDI<DICompositeType>(CompositeType), IsLocalToUnit,
      IsDefinition, ScopeLine, Flags, IsOptimized, unwrap<Function>(Func));
  return wrap(SP);
}


LLVMMetadataRef LLVMDIBuilderCreateLexicalBlock(LLVMDIBuilderRef Dref,
                                                LLVMMetadataRef Scope,
                                                LLVMMetadataRef File,
                                                unsigned Line,
                                                unsigned Column) {
  DIBuilder *D = unwrap(Dref);
  DILexicalBlock LB = D->createLexicalBlock(
#if HAVE_LLVM_35
      unwrapDI<DIDescriptor>(Scope), unwrapDI<DIFile>(File), Line, Column, 0);
#else
      unwrapDI<DIDescriptor>(Scope), unwrapDI<DIFile>(File), Line, Column);
#endif
  return wrap(LB);
}


LLVMMetadataRef LLVMDIBuilderCreateBasicType(LLVMDIBuilderRef Dref,
                                             const char *Name,
                                             uint64_t SizeInBits,
                                             uint64_t AlignInBits,
                                             unsigned Encoding) {
  DIBuilder *D = unwrap(Dref);
  DIBasicType T = D->createBasicType(Name, SizeInBits, AlignInBits, Encoding);
  return wrap(T);
}


LLVMMetadataRef LLVMDIBuilderGetOrCreateTypeArray(LLVMDIBuilderRef Dref,
                                                  LLVMMetadataRef *Data,
                                                  size_t Length) {
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
}

LLVMMetadataRef LLVMDIBuilderGetOrCreateArray(LLVMDIBuilderRef dref, LLVMMetadataRef *data, size_t length) {
  DIBuilder *D = unwrap(dref);
  ArrayRef<Metadata *> elements(unwrap(data), length);
  DIArray a = D->getOrCreateArray(elements);

  return wrap(a);
}


LLVMMetadataRef
LLVMDIBuilderCreateSubroutineType(LLVMDIBuilderRef Dref, LLVMMetadataRef File,
                                  LLVMMetadataRef ParameterTypes) {
  DIBuilder *D = unwrap(Dref);
  DICompositeType CT = D->createSubroutineType(
#if HAVE_LLVM_35
      unwrapDI<DIFile>(File), unwrapDI<DIArray>(ParameterTypes));
#else
      unwrapDI<DIFile>(File), unwrapDI<DITypeArray>(ParameterTypes));
#endif
  return wrap(CT);
}

LLVMMetadataRef LLVMDIBuilderCreateLocalVariable(
    LLVMDIBuilderRef Dref, unsigned Tag, LLVMMetadataRef Scope,
    const char *Name, LLVMMetadataRef File, unsigned Line, LLVMMetadataRef Ty,
    int AlwaysPreserve, unsigned Flags, unsigned ArgNo) {
  DIBuilder *D = unwrap(Dref);
  DIVariable V = D->createLocalVariable(
      Tag, unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), Line,
      unwrapDI<DIType>(Ty), AlwaysPreserve, Flags, ArgNo);
  return wrap(V);
}

LLVMValueRef LLVMDIBuilderInsertDeclareAtEnd(LLVMDIBuilderRef Dref,
                                             LLVMValueRef Storage,
                                             LLVMMetadataRef VarInfo,
                                             LLVMMetadataRef Expr,
                                             LLVMBasicBlockRef Block) {
  DIBuilder *D = unwrap(Dref);
  Instruction *Instr =
      D->insertDeclare(unwrap(Storage),
        unwrapDI<DIVariable>(VarInfo),
#ifdef HAVE_LLVM_35
#else
        unwrapDI<DIExpression>(Expr),
#endif
        unwrap(Block));
  return wrap(Instr);
}

LLVMMetadataRef LLVMDIBuilderCreateExpression(LLVMDIBuilderRef Dref,
                                              int64_t *Addr, size_t Length) {
#ifdef HAVE_LLVM_35
  return nullptr;
#else
  DIBuilder *D = unwrap(Dref);
  DIExpression Expr = D->createExpression(ArrayRef<int64_t>(Addr, Length));
  return wrap(Expr);
#endif
}

LLVMMetadataRef LLVMDIBuilderCreateEnumerationType(LLVMDIBuilderRef Dref,
  LLVMMetadataRef scope, const char* name, LLVMMetadataRef file, unsigned lineNumber,
  uint64_t sizeInBits, uint64_t alignInBits, LLVMMetadataRef elements, LLVMMetadataRef underlyingType) {

  DIBuilder *D = unwrap(Dref);
  DICompositeType enumType = D->createEnumerationType(unwrapDI<DIDescriptor>(scope), name,
        unwrapDI<DIFile>(file), lineNumber, sizeInBits, alignInBits, unwrapDI<DIArray>(elements),
        unwrapDI<DIType>(underlyingType));

  return wrap(enumType);
}

LLVMMetadataRef LLVMDIBuilderCreateEnumerator(LLVMDIBuilderRef dref, const char* name, int64_t value) {
  DIBuilder *D = unwrap(dref);
  DIEnumerator e = D->createEnumerator(name, value);
  return wrap(e);
}

LLVMMetadataRef LLVMDIBuilderCreateStructType(
    LLVMDIBuilderRef Dref, LLVMMetadataRef Scope, const char *Name,
    LLVMMetadataRef File, unsigned Line, uint64_t SizeInBits,
    uint64_t AlignInBits, unsigned Flags, LLVMMetadataRef DerivedFrom,
    LLVMMetadataRef ElementTypes) {
  DIBuilder *D = unwrap(Dref);
  DICompositeType CT = D->createStructType(
      unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), Line,
      SizeInBits, AlignInBits, Flags, unwrapDI<DIType>(DerivedFrom),
      unwrapDI<DIArray>(ElementTypes));
  return wrap(CT);
}

LLVMMetadataRef
LLVMDIBuilderCreateMemberType(LLVMDIBuilderRef Dref, LLVMMetadataRef Scope,
                              const char *Name, LLVMMetadataRef File,
                              unsigned Line, uint64_t SizeInBits,
                              uint64_t AlignInBits, uint64_t OffsetInBits,
                              unsigned Flags, LLVMMetadataRef Ty) {
  DIBuilder *D = unwrap(Dref);
  DIDerivedType DT = D->createMemberType(
      unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), Line,
      SizeInBits, AlignInBits, OffsetInBits, Flags, unwrapDI<DIType>(Ty));
  return wrap(DT);
}

LLVMMetadataRef LLVMDIBuilderCreatePointerType(LLVMDIBuilderRef Dref,
                                               LLVMMetadataRef PointeeType,
                                               uint64_t SizeInBits,
                                               uint64_t AlignInBits,
                                               const char *Name) {
  DIBuilder *D = unwrap(Dref);
  DIDerivedType T = D->createPointerType(unwrapDI<DIType>(PointeeType),
                                         SizeInBits, AlignInBits, Name);
  return wrap(T);
}

LLVMMetadataRef LLVMTemporaryMDNode(LLVMContextRef C, LLVMMetadataRef *MDs, unsigned Count) {
  return wrap(MDNode::getTemporary(*unwrap(C), ArrayRef<Metadata *>(unwrap(MDs), Count)));
}

void LLVMMetadataReplaceAllUsesWith(LLVMMetadataRef MD, LLVMMetadataRef New) {
#ifdef HAVE_LLVM_35
  auto *Node = unwrap<MDNode>(MD);
#else
  auto *Node = unwrap<MDNodeFwdDecl>(MD);
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
