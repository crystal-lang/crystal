#include "llvm/IR/DIBuilder.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/CBindingWrapping.h"
#include <llvm-c/Core.h>
#include <llvm/IR/DebugLoc.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Metadata.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/ADT/Triple.h>
#include <llvm-c/TargetMachine.h>
#include <llvm/Target/TargetMachine.h>
#include <llvm-c/ExecutionEngine.h>
#include <llvm/ExecutionEngine/ExecutionEngine.h>
#include <llvm/ExecutionEngine/RTDyldMemoryManager.h>

using namespace llvm;

#define LLVM_VERSION_GE(major, minor) \
  (LLVM_VERSION_MAJOR > (major) || LLVM_VERSION_MAJOR == (major) && LLVM_VERSION_MINOR >= (minor))

#define LLVM_VERSION_EQ(major, minor) \
  (LLVM_VERSION_MAJOR == (major) && LLVM_VERSION_MINOR == (minor))

#define LLVM_VERSION_LE(major, minor) \
  (LLVM_VERSION_MAJOR < (major) || LLVM_VERSION_MAJOR == (major) && LLVM_VERSION_MINOR <= (minor))

#if LLVM_VERSION_GE(7, 0)
#include <llvm/Target/CodeGenCWrappers.h>
#else
#include <llvm/Support/CodeGenCWrappers.h>
#endif

#if LLVM_VERSION_GE(6, 0)
#include <llvm-c/DebugInfo.h>
#endif

#if LLVM_VERSION_GE(4, 0)
#include <llvm/Bitcode/BitcodeWriter.h>
#include <llvm/Analysis/ModuleSummaryAnalysis.h>
#endif

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

LLVMDIBuilderRef LLVMExtNewDIBuilder(LLVMModuleRef mref) {
  Module *m = unwrap(mref);
  return wrap(new DIBuilder(*m));
}

// Missing LLVMDIBuilderFinalize in LLVM <= 5.0
void LLVMExtDIBuilderFinalize(LLVMDIBuilderRef dref) { unwrap(dref)->finalize(); }

LLVMMetadataRef LLVMExtDIBuilderCreateFile(
    DIBuilderRef Dref, const char *File, const char *Dir) {
  return wrap(Dref->createFile(File, Dir));
}

LLVMMetadataRef LLVMExtDIBuilderCreateCompileUnit(
    DIBuilderRef Dref, unsigned Lang, const char *File, const char *Dir,
    const char *Producer, int Optimized, const char *Flags,
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

LLVMMetadataRef LLVMExtDIBuilderCreateFunction(
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
#if LLVM_VERSION_GE(8, 0)
  DISubprogram *Sub = Dref->createFunction(
      unwrapDI<DIScope>(Scope), StringRef(Name), StringRef(LinkageName), unwrapDI<DIFile>(File), Line,
      unwrapDI<DISubroutineType>(CompositeType),
      ScopeLine, Flags, DISubprogram::toSPFlags(IsLocalToUnit, IsDefinition, IsOptimized));
#else
  DISubprogram *Sub = Dref->createFunction(
      unwrapDI<DIScope>(Scope), Name, LinkageName, unwrapDI<DIFile>(File), Line,
      unwrapDI<DISubroutineType>(CompositeType), IsLocalToUnit, IsDefinition,
      ScopeLine, Flags, IsOptimized);
#endif
  unwrap<Function>(Func)->setSubprogram(Sub);
  return wrap(Sub);
}

LLVMMetadataRef LLVMExtDIBuilderCreateLexicalBlock(
    DIBuilderRef Dref, LLVMMetadataRef Scope, LLVMMetadataRef File,
    unsigned Line, unsigned Column) {
  return wrap(Dref->createLexicalBlock(unwrapDI<DIDescriptor>(Scope),
                                       unwrapDI<DIFile>(File), Line, Column));
}

LLVMMetadataRef LLVMExtDIBuilderCreateBasicType(
    DIBuilderRef Dref, const char *Name, uint64_t SizeInBits,
    uint64_t AlignInBits, unsigned Encoding) {
#if LLVM_VERSION_LE(3, 9)
  return wrap(Dref->createBasicType(Name, SizeInBits, AlignInBits, Encoding));
#else
  return wrap(Dref->createBasicType(Name, SizeInBits, Encoding));
#endif
}

LLVMMetadataRef LLVMExtDIBuilderGetOrCreateTypeArray(
    DIBuilderRef Dref, LLVMMetadataRef *Data, unsigned Length) {
  Metadata **DataValue = unwrap(Data);
  return wrap(
      Dref->getOrCreateTypeArray(ArrayRef<Metadata *>(DataValue, Length))
          .get());
}

LLVMMetadataRef LLVMExtDIBuilderGetOrCreateArray(
    DIBuilderRef Dref, LLVMMetadataRef *Data, unsigned Length) {
  Metadata **DataValue = unwrap(Data);
  return wrap(
      Dref->getOrCreateArray(ArrayRef<Metadata *>(DataValue, Length)).get());
}

LLVMMetadataRef LLVMExtDIBuilderCreateSubroutineType(
    DIBuilderRef Dref, LLVMMetadataRef File, LLVMMetadataRef ParameterTypes) {
  DISubroutineType *CT = Dref->createSubroutineType(DITypeRefArray(unwrap<MDTuple>(ParameterTypes)));
  return wrap(CT);
}

LLVMMetadataRef LLVMExtDIBuilderCreateAutoVariable(
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

LLVMMetadataRef LLVMExtDIBuilderCreateParameterVariable(
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

LLVMValueRef LLVMExtDIBuilderInsertDeclareAtEnd(
    DIBuilderRef Dref, LLVMValueRef Storage, LLVMMetadataRef VarInfo,
    LLVMMetadataRef Expr, LLVMValueRef DL, LLVMBasicBlockRef Block) {
  Instruction *Instr =
    Dref->insertDeclare(unwrap(Storage), unwrap<DILocalVariable>(VarInfo),
                        unwrapDI<DIExpression>(Expr),
                        DebugLoc(cast<MDNode>(unwrap<MetadataAsValue>(DL)->getMetadata())),
                        unwrap(Block));
  return wrap(Instr);
}

LLVMMetadataRef LLVMExtDIBuilderCreateExpression(
    DIBuilderRef Dref, int64_t *Addr, size_t Length) {
  return wrap(Dref->createExpression(ArrayRef<int64_t>(Addr, Length)));
}

LLVMMetadataRef LLVMExtDIBuilderCreateEnumerationType(
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

LLVMMetadataRef LLVMExtDIBuilderCreateEnumerator(
    DIBuilderRef Dref, const char *Name, int64_t Value) {
  DIEnumerator *e = Dref->createEnumerator(Name, Value);
  return wrap(e);
}

LLVMMetadataRef LLVMExtDIBuilderCreateStructType(
    DIBuilderRef Dref, LLVMMetadataRef Scope, const char *Name,
    LLVMMetadataRef File, unsigned Line, uint64_t SizeInBits,
    uint64_t AlignInBits,
#if LLVM_VERSION_LE(3, 9)
    unsigned Flags,
#else
    DINode::DIFlags Flags,
#endif
    LLVMMetadataRef DerivedFrom, LLVMMetadataRef Elements) {
  DICompositeType *CT = Dref->createStructType(
      unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), Line,
      SizeInBits, AlignInBits, Flags, unwrapDI<DIType>(DerivedFrom),
      DINodeArray(unwrapDI<MDTuple>(Elements)));
  return wrap(CT);
}

LLVMMetadataRef LLVMExtDIBuilderCreateUnionType(
    DIBuilderRef Dref, LLVMMetadataRef Scope, const char *Name,
    LLVMMetadataRef File, unsigned Line, uint64_t SizeInBits,
    uint64_t AlignInBits,
#if LLVM_VERSION_LE(3, 9)
    unsigned Flags,
#else
    DINode::DIFlags Flags,
#endif
    LLVMMetadataRef Elements) {
  DICompositeType *CT = Dref->createUnionType(
      unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), Line,
      SizeInBits, AlignInBits, Flags,
      DINodeArray(unwrapDI<MDTuple>(Elements)));
  return wrap(CT);
}

LLVMMetadataRef LLVMExtDIBuilderCreateArrayType(
    DIBuilderRef Dref, uint64_t Size, uint64_t AlignInBits,
    LLVMMetadataRef Type, LLVMMetadataRef Subs) {
      return wrap(Dref->createArrayType(Size, AlignInBits, unwrapDI<DIType>(Type), DINodeArray(unwrapDI<MDTuple>(Subs))));
}


LLVMMetadataRef LLVMExtDIBuilderCreateReplaceableCompositeType(
  DIBuilderRef Dref, LLVMMetadataRef Scope, const char *Name,
  LLVMMetadataRef File, unsigned Line) {
  DICompositeType *CT = Dref->createReplaceableCompositeType(llvm::dwarf::DW_TAG_structure_type,
                                                             Name,
                                                             unwrapDI<DIScope>(Scope),
                                                             unwrapDI<DIFile>(File),
                                                             Line);
  return wrap(CT);
}

// LLVM 7.0 LLVMDIBuilderCreateUnspecifiedType
LLVMMetadataRef LLVMExtDIBuilderCreateUnspecifiedType(
  DIBuilderRef Dref, const char *Name, size_t NameLen) {
  return wrap(Dref->createUnspecifiedType({Name, NameLen}));
}

// LLVM 7.0 LLVMDIBuilderCreateLexicalBlockFile
LLVMMetadataRef LLVMExtDIBuilderCreateLexicalBlockFile(
  DIBuilderRef Dref,
  LLVMMetadataRef Scope, LLVMMetadataRef File, unsigned Discriminator) {
  return wrap(Dref->createLexicalBlockFile(unwrapDI<DIScope>(Scope),
                                           unwrapDI<DIFile>(File),
                                           Discriminator));
}

void LLVMExtDIBuilderReplaceTemporary(
  DIBuilderRef Dref, LLVMMetadataRef From, LLVMMetadataRef To) {
  auto *Node = unwrap<MDNode>(From);
  auto *Type = unwrap<DIType>(To);

  llvm::TempMDNode fwd_decl(Node);
  Dref->replaceTemporary(std::move(fwd_decl), Type);
}

LLVMMetadataRef LLVMExtDIBuilderCreateMemberType(
    DIBuilderRef Dref, LLVMMetadataRef Scope, const char *Name, LLVMMetadataRef File,
    unsigned Line, uint64_t SizeInBits, uint64_t AlignInBits, uint64_t OffsetInBits,
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

LLVMMetadataRef LLVMExtDIBuilderCreatePointerType(
    DIBuilderRef Dref, LLVMMetadataRef PointeeType,
    uint64_t SizeInBits, uint64_t AlignInBits, const char *Name) {
  DIDerivedType *T = Dref->createPointerType(unwrapDI<DIType>(PointeeType),
                                             SizeInBits, AlignInBits,
#if LLVM_VERSION_GE(5, 0)
                                             None,
#endif
                                             Name);
  return wrap(T);
}

LLVMMetadataRef LLVMTemporaryMDNode2(
    LLVMContextRef C, LLVMMetadataRef *MDs, unsigned Count) {
  return wrap(MDTuple::getTemporary(*unwrap(C),
                                    ArrayRef<Metadata *>(unwrap(MDs), Count))
                  .release());
}

void LLVMMetadataReplaceAllUsesWith2(
  LLVMMetadataRef MD, LLVMMetadataRef New) {
  auto *Node = unwrap<MDNode>(MD);
  Node->replaceAllUsesWith(unwrap<MDNode>(New));
  MDNode::deleteTemporary(Node);
}

void LLVMExtSetCurrentDebugLocation(
  LLVMBuilderRef Bref, unsigned Line, unsigned Col, LLVMMetadataRef Scope,
  LLVMMetadataRef InlinedAt) {
  unwrap(Bref)->SetCurrentDebugLocation(
      DebugLoc::get(Line, Col, Scope ? unwrap<MDNode>(Scope) : nullptr,
                    InlinedAt ? unwrap<MDNode>(InlinedAt) : nullptr));
}

LLVMValueRef LLVMExtBuildCmpxchg(
    LLVMBuilderRef B, LLVMValueRef PTR, LLVMValueRef Cmp, LLVMValueRef New,
    LLVMAtomicOrdering SuccessOrdering, LLVMAtomicOrdering FailureOrdering) {
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

LLVMValueRef LLVMExtBuildCatchPad(
    LLVMBuilderRef B, LLVMValueRef ParentPad, unsigned ArgCount,
    LLVMValueRef *LLArgs, const char *Name) {
#if LLVM_VERSION_GE(3, 8)
  Value **Args = unwrap(LLArgs);
  return wrap(unwrap(B)->CreateCatchPad(
      unwrap(ParentPad), ArrayRef<Value *>(Args, ArgCount), Name));
#else
  return nullptr;
#endif
}

LLVMValueRef LLVMExtBuildCatchRet(
    LLVMBuilderRef B, LLVMValueRef Pad, LLVMBasicBlockRef BB) {
#if LLVM_VERSION_GE(3, 8)
  return wrap(unwrap(B)->CreateCatchRet(cast<CatchPadInst>(unwrap(Pad)),
                                              unwrap(BB)));
#else
  return nullptr;
#endif
}

LLVMValueRef LLVMExtBuildCatchSwitch(
    LLVMBuilderRef B, LLVMValueRef ParentPad, LLVMBasicBlockRef BB,
    unsigned NumHandlers, const char *Name) {
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

void LLVMExtAddHandler(LLVMValueRef CatchSwitchRef, LLVMBasicBlockRef Handler) {
#if LLVM_VERSION_GE(3, 8)
  Value *CatchSwitch = unwrap(CatchSwitchRef);
  cast<CatchSwitchInst>(CatchSwitch)->addHandler(unwrap(Handler));
#endif
}

OperandBundleDef *LLVMExtBuildOperandBundleDef(
    const char *Name, LLVMValueRef *Inputs, unsigned NumInputs) {
#if LLVM_VERSION_GE(3, 8)
  return new OperandBundleDef(Name, makeArrayRef(unwrap(Inputs), NumInputs));
#else
  return nullptr;
#endif
}

LLVMValueRef LLVMExtBuildCall(
    LLVMBuilderRef B, LLVMValueRef Fn, LLVMValueRef *Args, unsigned NumArgs,
    OperandBundleDef *Bundle, const char *Name) {
#if LLVM_VERSION_GE(3, 8)
  unsigned Len = Bundle ? 1 : 0;
  ArrayRef<OperandBundleDef> Bundles = makeArrayRef(Bundle, Len);
  return wrap(unwrap(B)->CreateCall(
      unwrap(Fn), makeArrayRef(unwrap(Args), NumArgs), Bundles, Name));
#else
  return LLVMBuildCall(B, Fn, Args, NumArgs, Name);
#endif
}

LLVMValueRef LLVMExtBuildInvoke(
    LLVMBuilderRef B, LLVMValueRef Fn, LLVMValueRef *Args, unsigned NumArgs,
    LLVMBasicBlockRef Then, LLVMBasicBlockRef Catch, OperandBundleDef *Bundle,
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


void LLVMExtWriteBitcodeWithSummaryToFile(LLVMModuleRef mref, const char *File) {
#if LLVM_VERSION_GE(4, 0)
  // https://github.com/ldc-developers/ldc/pull/1840/files
  Module *m = unwrap(mref);

  std::error_code EC;
  raw_fd_ostream OS(File, EC, sys::fs::F_None);
  if (EC) return;

  llvm::ModuleSummaryIndex moduleSummaryIndex = llvm::buildModuleSummaryIndex(*m, nullptr, nullptr);
#if LLVM_VERSION_GE(7, 0)
  llvm::WriteBitcodeToFile(*m, OS, true, &moduleSummaryIndex, true);
#else
  llvm::WriteBitcodeToFile(m, OS, true, &moduleSummaryIndex, true);
#endif
#endif
}

// Missing LLVMNormalizeTargetTriple in LLVM <= 7.0
char *LLVMExtNormalizeTargetTriple(const char* triple) {
  return strdup(Triple::normalize(StringRef(triple)).c_str());
}

char *LLVMExtBasicBlockName(LLVMBasicBlockRef BB) {
#if LLVM_VERSION_GE(4, 0)
  // It seems to work since llvm-4.0 https://stackoverflow.com/a/46045548/30948
  return strdup(unwrap(BB)->getName().data());
#else
  return NULL;
#endif
}

static TargetMachine *unwrap(LLVMTargetMachineRef P) {
  return reinterpret_cast<TargetMachine *>(P);
}

void LLVMExtTargetMachineEnableGlobalIsel(LLVMTargetMachineRef T, LLVMBool Enable) {
#if LLVM_VERSION_GE(7, 0)
  unwrap(T)->setGlobalISel(Enable);
#endif
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
  #if LLVM_VERSION_GE(7, 0)
    targetOptions.EnableGlobalISel = EnableGlobalISel;
  #endif
  std::unique_ptr<Module> Mod(unwrap(M));

  if (Mod)
    // Set function attribute "frame-pointer" based on
    // NoFramePointerElim.
    for (auto &F : *Mod) {
      auto Attrs = F.getAttributes();
      StringRef Value = options.NoFramePointerElim ? "all" : "none";
      Attrs = Attrs.addAttribute(F.getContext(), AttributeList::FunctionIndex,
                                 "frame-pointer", Value);
      F.setAttributes(Attrs);
    }


  std::string Error;
  EngineBuilder builder(std::move(Mod));
  builder.setEngineKind(EngineKind::JIT)
         .setErrorStr(&Error)
         .setOptLevel((CodeGenOpt::Level)options.OptLevel)
         .setTargetOptions(targetOptions);
  bool JIT;
  if (Optional<CodeModel::Model> CM = unwrap(options.CodeModel, JIT))
    builder.setCodeModel(*CM);
  if (options.MCJMM)
    builder.setMCJITMemoryManager(
      std::unique_ptr<RTDyldMemoryManager>(unwrap(options.MCJMM)));

  TargetMachine* tm = builder.selectTarget();
  #if LLVM_VERSION_GE(7, 0)
    tm->setGlobalISel(EnableGlobalISel);
  #endif

  if (ExecutionEngine *JIT = builder.create(tm)) {
    *OutJIT = wrap(JIT);
    return 0;
  }
  *OutError = strdup(Error.c_str());
  return 1;
}

LLVMMetadataRef LLVMExtDIBuilderGetOrCreateArraySubrange(
  DIBuilderRef Dref, uint64_t Lo,
  uint64_t Count) {
    return wrap(Dref->getOrCreateSubrange(Lo, Count));
  }
}
