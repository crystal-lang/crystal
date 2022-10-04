@[Link("DbgHelp")]
lib LibC
  MAX_SYM_NAME = 2000

  SYMOPT_UNDNAME              = 0x00000002
  SYMOPT_LOAD_LINES           = 0x00000010
  SYMOPT_FAIL_CRITICAL_ERRORS = 0x00000200
  SYMOPT_NO_PROMPTS           = 0x00080000

  struct SYMBOL_INFOW
    sizeOfStruct : DWORD
    typeIndex : DWORD
    reserved : DWORD64[2]
    index : DWORD
    size : DWORD
    modBase : DWORD64
    flags : DWORD
    value : DWORD64
    address : DWORD64
    register : DWORD
    scope : DWORD
    tag : DWORD
    nameLen : DWORD
    maxNameLen : DWORD
    name : WCHAR[1] # VLA
  end

  struct IMAGEHLP_LINEW64
    sizeOfStruct : DWORD
    key : Void*
    lineNumber : DWORD
    fileName : LPWSTR
    address : DWORD64
  end

  alias SYM_TYPE = DWORD

  struct IMAGEHLP_MODULEW64
    sizeOfStruct : DWORD
    baseOfImage : DWORD64
    imageSize : DWORD
    timeDateStamp : DWORD
    checkSum : DWORD
    numSyms : DWORD
    symType : SYM_TYPE
    moduleName : WCHAR[32]
    imageName : WCHAR[256]
    loadedImageName : WCHAR[256]
    loadedPdbName : WCHAR[256]
    cVSig : DWORD
    cVData : WCHAR[780] # MAX_PATH * 3
    pdbSig : DWORD
    pdbSig70 : GUID
    pdbAge : DWORD
    pdbUnmatched : BOOL
    dbgUnmatched : BOOL
    lineNumbers : BOOL
    globalSymbols : BOOL
    typeInfo : BOOL
    sourceIndexed : BOOL
    publics : BOOL
    machineType : DWORD
    reserved : DWORD
  end

  fun SymInitializeW(hProcess : HANDLE, userSearchPath : LPWSTR, fInvadeProcess : BOOL) : BOOL
  fun SymCleanup(hProcess : HANDLE) : BOOL
  fun SymGetOptions : DWORD
  fun SymSetOptions(symOptions : DWORD) : DWORD
  fun SymFromAddrW(hProcess : HANDLE, address : DWORD64, displacement : DWORD64*, symbol : SYMBOL_INFOW*) : BOOL
  fun SymGetLineFromAddrW64(hProcess : HANDLE, dwAddr : DWORD64, pdwDisplacement : DWORD*, line : IMAGEHLP_LINEW64*) : BOOL
  fun SymGetModuleInfoW64(hProcess : HANDLE, qwAddr : DWORD64, moduleInfo : IMAGEHLP_MODULEW64*) : BOOL

  # fun SymFunctionTableAccess64(hProcess : HANDLE, addrBase : DWORD64) : Void*
  fun SymGetModuleBase64(hProcess : HANDLE, qwAddr : DWORD64) : DWORD64

  enum ADDRESS_MODE
    AddrMode1616
    AddrMode1632
    AddrModeReal
    AddrModeFlat
  end

  struct ADDRESS64
    offset : DWORD64
    segment : WORD
    mode : ADDRESS_MODE
  end

  struct KDHELP64
    thread : DWORD64
    thCallbackStack : DWORD
    thCallbackBStore : DWORD
    nextCallback : DWORD
    framePointer : DWORD
    kiCallUserMode : DWORD64
    keUserCallbackDispatcher : DWORD64
    systemRangeStart : DWORD64
    kiUserExceptionDispatcher : DWORD64
    stackBase : DWORD64
    stackLimit : DWORD64
    buildVersion : DWORD
    retpolineStubFunctionTableSize : DWORD
    retpolineStubFunctionTable : DWORD64
    retpolineStubOffset : DWORD
    retpolineStubSize : DWORD
    reserved0 : DWORD64[2]
  end

  struct STACKFRAME64
    addrPC : ADDRESS64
    addrReturn : ADDRESS64
    addrFrame : ADDRESS64
    addrStack : ADDRESS64
    addrBStore : ADDRESS64
    funcTableEntry : Void*
    params : DWORD64[4]
    far : BOOL
    virtual : BOOL
    reserved : DWORD64[3]
    kdHelp : KDHELP64
  end

  IMAGE_FILE_MACHINE_AMD64 = DWORD.new!(0x8664)

  alias PREAD_PROCESS_MEMORY_ROUTINE64 = HANDLE, DWORD64, Void*, DWORD, DWORD* -> BOOL
  alias PFUNCTION_TABLE_ACCESS_ROUTINE64 = HANDLE, DWORD64 -> Void*
  alias PGET_MODULE_BASE_ROUTINE64 = HANDLE, DWORD64 -> DWORD64
  alias PTRANSLATE_ADDRESS_ROUTINE64 = HANDLE, HANDLE, ADDRESS64* -> DWORD64

  fun StackWalk64(
    machineType : DWORD, hProcess : HANDLE, hThread : HANDLE, stackFrame : STACKFRAME64*, contextRecord : Void*,
    readMemoryRoutine : PREAD_PROCESS_MEMORY_ROUTINE64, functionTableAccessRoutine : PFUNCTION_TABLE_ACCESS_ROUTINE64,
    getModuleBaseRoutine : PGET_MODULE_BASE_ROUTINE64, translateAddress : PTRANSLATE_ADDRESS_ROUTINE64
  ) : BOOL
end
