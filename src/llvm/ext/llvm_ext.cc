#include <llvm/IR/DIBuilder.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/Module.h>
#include <llvm/Support/CBindingWrapping.h>
#include <llvm/IR/DebugLoc.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Metadata.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/Support/FileSystem.h>
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
#include <llvm/Bitcode/BitcodeWriter.h>
#include <llvm/Analysis/ModuleSummaryAnalysis.h>

typedef DIBuilder *DIBuilderRef;
#define DIArray DINodeArray
template <typename T> T *unwrapDIptr(LLVMMetadataRef v) {
  return (T *)(v ? unwrap<MDNode>(v) : NULL);
}

#define DIDescriptor DIScope
#define unwrapDI unwrapDIptr

extern "C" {

LLVMDIBuilderRef LLVMExtNewDIBuilder(LLVMModuleRef mref) {
  Module *m = unwrap(mref);
  return wrap(new DIBuilder(*m));
}

LLVMMetadataRef LLVMExtDIBuilderCreateFile(
    DIBuilderRef Dref, const char *File, const char *Dir) {
  return wrap(Dref->createFile(File, Dir));
}

LLVMMetadataRef LLVMExtDIBuilderCreateCompileUnit(
    DIBuilderRef Dref, unsigned Lang, const char *File, const char *Dir,
    const char *Producer, int Optimized, const char *Flags,
    unsigned RuntimeVersion) {
  DIFile *F = Dref->createFile(File, Dir);
  return wrap(Dref->createCompileUnit(Lang, F, Producer, Optimized,
                                      Flags, RuntimeVersion));
}

LLVMMetadataRef LLVMExtDIBuilderCreateFunction(
    DIBuilderRef Dref, LLVMMetadataRef Scope, const char *Name,
    const char *LinkageName, LLVMMetadataRef File, unsigned Line,
    LLVMMetadataRef CompositeType, bool IsLocalToUnit, bool IsDefinition,
    unsigned ScopeLine,
    DINode::DIFlags Flags,
    bool IsOptimized,
    LLVMValueRef Func) {
  DISubprogram *Sub = Dref->createFunction(
      unwrapDI<DIScope>(Scope), StringRef(Name), StringRef(LinkageName), unwrapDI<DIFile>(File), Line,
      unwrapDI<DISubroutineType>(CompositeType),
      ScopeLine, Flags, DISubprogram::toSPFlags(IsLocalToUnit, IsDefinition, IsOptimized));
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
  return wrap(Dref->createBasicType(Name, SizeInBits, Encoding));
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
    DINode::DIFlags Flags,
    uint32_t AlignInBits) {
  DILocalVariable *V = Dref->createAutoVariable(
      unwrapDI<DIDescriptor>(Scope), Name, unwrapDI<DIFile>(File), Line,
      unwrapDI<DIType>(Ty), AlwaysPreserve, Flags, AlignInBits);
  return wrap(V);
}

LLVMMetadataRef LLVMExtDIBuilderCreateParameterVariable(
    DIBuilderRef Dref, LLVMMetadataRef Scope, const char *Name,
    unsigned ArgNo, LLVMMetadataRef File, unsigned Line,
    LLVMMetadataRef Ty, int AlwaysPreserve,
    DINode::DIFlags Flags
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
    DIBuilderRef Dref, uint64_t *Addr, size_t Length) {
  return wrap(Dref->createExpression(ArrayRef<uint64_t>(Addr, Length)));
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
    DINode::DIFlags Flags,
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
    DINode::DIFlags Flags,
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
    DINode::DIFlags Flags,
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
                                             None,
                                             Name);
  return wrap(T);
}

void LLVMExtSetCurrentDebugLocation(
  LLVMBuilderRef Bref, unsigned Line, unsigned Col, LLVMMetadataRef Scope,
  LLVMMetadataRef InlinedAt) {
#if LLVM_VERSION_GE(12, 0)
  if (!Scope)
    unwrap(Bref)->SetCurrentDebugLocation(DebugLoc());
  else
    unwrap(Bref)->SetCurrentDebugLocation(
      DILocation::get(unwrap<MDNode>(Scope)->getContext(), Line, Col,
                      unwrapDI<DILocalScope>(Scope),
                      unwrapDI<DILocation>(InlinedAt)));
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

void LLVMExtWriteBitcodeWithSummaryToFile(LLVMModuleRef mref, const char *File) {
  // https://github.com/ldc-developers/ldc/pull/1840/files
  Module *m = unwrap(mref);

  std::error_code EC;
#if LLVM_VERSION_GE(13, 0)
  raw_fd_ostream OS(File, EC, sys::fs::OF_None);
#else
  raw_fd_ostream OS(File, EC, sys::fs::F_None);
#endif
  if (EC) return;

  llvm::ModuleSummaryIndex moduleSummaryIndex = llvm::buildModuleSummaryIndex(*m, nullptr, nullptr);
  llvm::WriteBitcodeToFile(*m, OS, true, &moduleSummaryIndex, true);
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
  if (Optional<CodeModel::Model> CM = unwrap(options.CodeModel, JIT))
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

LLVMMetadataRef LLVMExtDIBuilderGetOrCreateArraySubrange(
  DIBuilderRef Dref, uint64_t Lo,
  uint64_t Count) {
    return wrap(Dref->getOrCreateSubrange(Lo, Count));
  }
}
