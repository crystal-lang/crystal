require "c/int_safe"

lib LibC
  alias BOOLEAN = BYTE
  alias LONG = Int32
  alias LARGE_INTEGER = Int64

  alias CHAR = UChar
  alias WCHAR = UInt16
  alias LPSTR = CHAR*
  alias LPWSTR = WCHAR*
  alias LPWCH = WCHAR*

  alias HANDLE = Void*
  alias HMODULE = Void*

  INVALID_FILE_ATTRIBUTES      = DWORD.new!(-1)
  FILE_ATTRIBUTE_DIRECTORY     =  0x10
  FILE_ATTRIBUTE_HIDDEN        =   0x2
  FILE_ATTRIBUTE_READONLY      =   0x1
  FILE_ATTRIBUTE_REPARSE_POINT = 0x400
  FILE_ATTRIBUTE_SYSTEM        =   0x4

  FILE_APPEND_DATA = 0x00000004

  DELETE                = 0x00010000
  FILE_READ_ATTRIBUTES  =       0x80
  FILE_WRITE_ATTRIBUTES =     0x0100

  MAXIMUM_REPARSE_DATA_BUFFER_SIZE = 0x4000

  IO_REPARSE_TAG_SYMLINK = 0xA000000C_u32
  IO_REPARSE_TAG_AF_UNIX = 0x80000023_u32

  # Memory protection constants
  PAGE_READWRITE =  0x04
  PAGE_GUARD     = 0x100

  PROCESS_QUERY_LIMITED_INFORMATION =     0x1000
  SYNCHRONIZE                       = 0x00100000

  DUPLICATE_CLOSE_SOURCE = 0x00000001
  DUPLICATE_SAME_ACCESS  = 0x00000002

  enum REGSAM
    # Required to query the values of a registry key.
    QUERY_VALUE = 0x0001

    # Required to create, delete, or set a registry value.
    SET_VALUE = 0x0002

    # Required to create a subkey of a registry key.
    CREATE_SUB_KEY = 0x0004

    # Required to enumerate the subkeys of a registry key.
    ENUMERATE_SUB_KEYS = 0x0008

    # Required to request change notifications for a registry key or for subkeys of a registry key.
    NOTIFY = 0x0010

    # Reserved for system use.
    CREATE_LINK = 0x0020

    # Indicates that an application on 64-bit Windows should operate on the 32-bit registry view. This flag is ignored by 32-bit Windows.
    # This flag must be combined using the OR operator with the other flags in this table that either query or access registry values.
    # Windows 2000: This flag is not supported.
    WOW64_32KEY = 0x0200

    # Indicates that an application on 64-bit Windows should operate on the 64-bit registry view. This flag is ignored by 32-bit Windows.
    # This flag must be combined using the OR operator with the other flags in this table that either query or access registry values.
    # Windows 2000: This flag is not supported.
    WOW64_64KEY = 0x0100

    WOW64_RES = 0x0300

    # Combines the `STANDARD_RIGHTS_READ`, `QUERY_VALUE`, `ENUMERATE_SUB_KEYS`, and `NOTIFY` values.
    # (STANDARD_RIGHTS_READ | QUERY_VALUE | ENUMERATE_SUB_KEYS | NOTIFY) & ~SYNCHRONIZE
    READ = 0x20019

    # Combines the `STANDARD_RIGHTS_REQUIRED`, `QUERY_VALUE`, `SET_VALUE`, `CREATE_SUB_KEY`, `ENUMERATE_SUB_KEYS`, `NOTIFY`, and `CREATE_LINK` access rights.
    # (STANDARD_RIGHTS_ALL | KEY_QUERY_VALUE | KEY_SET_VALUE | KEY_CREATE_SUB_KEY | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY | KEY_CREATE_LINK) & ~SYNCHRONIZE
    ALL_ACCESS = 0xf003f

    # Equivalent to `READ`.
    # KEY_READ & ~SYNCHRONIZE
    EXECUTE = 0x20019

    # Combines the STANDARD_RIGHTS_WRITE, `KEY_SET_VALUE`, and `KEY_CREATE_SUB_KEY` access rights.
    # (STANDARD_RIGHTS_WRITE | KEY_SET_VALUE | KEY_CREATE_SUB_KEY) & ~SYNCHRONIZE
    WRITE = 0x20006
  end

  struct CONTEXT
    p1Home : DWORD64
    p2Home : DWORD64
    p3Home : DWORD64
    p4Home : DWORD64
    p5Home : DWORD64
    p6Home : DWORD64
    contextFlags : DWORD
    mxCsr : DWORD
    segCs : WORD
    segDs : WORD
    segEs : WORD
    segFs : WORD
    segGs : WORD
    segSs : WORD
    eFlags : DWORD
    dr0 : DWORD64
    dr1 : DWORD64
    dr2 : DWORD64
    dr3 : DWORD64
    dr6 : DWORD64
    dr7 : DWORD64
    rax : DWORD64
    rcx : DWORD64
    rdx : DWORD64
    rbx : DWORD64
    rsp : DWORD64
    rbp : DWORD64
    rsi : DWORD64
    rdi : DWORD64
    r8 : DWORD64
    r9 : DWORD64
    r10 : DWORD64
    r11 : DWORD64
    r12 : DWORD64
    r13 : DWORD64
    r14 : DWORD64
    r15 : DWORD64
    rip : DWORD64
    fltSave : UInt8[512]           # DUMMYUNIONNAME
    vectorRegister : UInt8[16][26] # M128A[26]
    vectorControl : DWORD64
    debugControl : DWORD64
    lastBranchToRip : DWORD64
    lastBranchFromRip : DWORD64
    lastExceptionToRip : DWORD64
    lastExceptionFromRip : DWORD64
  end

  {% if flag?(:x86_64) %}
    CONTEXT_AMD64 = DWORD.new!(0x00100000)

    CONTEXT_CONTROL         = CONTEXT_AMD64 | 0x00000001
    CONTEXT_INTEGER         = CONTEXT_AMD64 | 0x00000002
    CONTEXT_SEGMENTS        = CONTEXT_AMD64 | 0x00000004
    CONTEXT_FLOATING_POINT  = CONTEXT_AMD64 | 0x00000008
    CONTEXT_DEBUG_REGISTERS = CONTEXT_AMD64 | 0x00000010

    CONTEXT_FULL = CONTEXT_CONTROL | CONTEXT_INTEGER | CONTEXT_FLOATING_POINT
  {% elsif flag?(:i386) %}
    CONTEXT_i386 = DWORD.new!(0x00010000i64)
    CONTEXT_i486 = DWORD.new!(0x00010000i64)

    CONTEXT_CONTROL            = CONTEXT_i386 | 0x00000001
    CONTEXT_INTEGER            = CONTEXT_i386 | 0x00000002
    CONTEXT_SEGMENTS           = CONTEXT_i386 | 0x00000004
    CONTEXT_FLOATING_POINT     = CONTEXT_i386 | 0x00000008
    CONTEXT_DEBUG_REGISTERS    = CONTEXT_i386 | 0x00000010
    CONTEXT_EXTENDED_REGISTERS = CONTEXT_i386 | 0x00000020

    CONTEXT_FULL = CONTEXT_CONTROL | CONTEXT_INTEGER | CONTEXT_SEGMENTS
  {% end %}

  fun RtlCaptureContext(contextRecord : CONTEXT*)

  struct EXCEPTION_RECORD64
    exceptionCode : DWORD
    exceptionFlags : DWORD
    exceptionRecord : DWORD64
    exceptionAddress : DWORD64
    numberParameters : DWORD
    __unusedAlignment : DWORD
    exceptionInformation : DWORD64[15]
  end

  struct EXCEPTION_POINTERS
    exceptionRecord : EXCEPTION_RECORD64*
    contextRecord : CONTEXT*
  end

  struct NT_TIB
    exceptionList : Void*
    stackBase : Void*
    stackLimit : Void*
    subSystemTib : Void*
    fiberData : Void*
    arbitraryUserPointer : Void*
    pvSelf : NT_TIB*
  end

  struct MEMORY_BASIC_INFORMATION
    baseAddress : Void*
    allocationBase : Void*
    allocationProtect : DWORD
    partitionId : WORD
    regionSize : SizeT
    state : DWORD
    protect : DWORD
    type : DWORD
  end

  IMAGE_NT_SIGNATURE = 0x00004550 # PE00

  struct IMAGE_DOS_HEADER
    e_magic : WORD
    e_cblp : WORD
    e_cp : WORD
    e_crlc : WORD
    e_cparhdr : WORD
    e_minalloc : WORD
    e_maxalloc : WORD
    e_ss : WORD
    e_sp : WORD
    e_csum : WORD
    e_ip : WORD
    e_cs : WORD
    e_lfarlc : WORD
    e_ovno : WORD
    e_res : WORD[4]
    e_oemid : WORD
    e_oeminfo : WORD
    e_res2 : WORD[10]
    e_lfanew : LONG
  end

  struct IMAGE_FILE_HEADER
    machine : WORD
    numberOfSections : WORD
    timeDateStamp : DWORD
    pointerToSymbolTable : DWORD
    numberOfSymbols : DWORD
    sizeOfOptionalHeader : WORD
    characteristics : WORD
  end

  struct IMAGE_DATA_DIRECTORY
    virtualAddress : DWORD
    size : DWORD
  end

  struct IMAGE_OPTIONAL_HEADER64
    magic : WORD
    majorLinkerVersion : BYTE
    minorLinkerVersion : BYTE
    sizeOfCode : DWORD
    sizeOfInitializedData : DWORD
    sizeOfUninitializedData : DWORD
    addressOfEntryPoint : DWORD
    baseOfCode : DWORD
    imageBase : ULongLong
    sectionAlignment : DWORD
    fileAlignment : DWORD
    majorOperatingSystemVersion : WORD
    minorOperatingSystemVersion : WORD
    majorImageVersion : WORD
    minorImageVersion : WORD
    majorSubsystemVersion : WORD
    minorSubsystemVersion : WORD
    win32VersionValue : DWORD
    sizeOfImage : DWORD
    sizeOfHeaders : DWORD
    checkSum : DWORD
    subsystem : WORD
    dllCharacteristics : WORD
    sizeOfStackReserve : ULongLong
    sizeOfStackCommit : ULongLong
    sizeOfHeapReserve : ULongLong
    sizeOfHeapCommit : ULongLong
    loaderFlags : DWORD
    numberOfRvaAndSizes : DWORD
    dataDirectory : IMAGE_DATA_DIRECTORY[16] # IMAGE_NUMBEROF_DIRECTORY_ENTRIES
  end

  struct IMAGE_NT_HEADERS64
    signature : DWORD
    fileHeader : IMAGE_FILE_HEADER
    optionalHeader : IMAGE_OPTIONAL_HEADER64
  end

  struct IMAGE_IMPORT_BY_NAME
    hint : WORD
    name : CHAR[1]
  end

  union IMAGE_THUNK_DATA64_u1
    forwarderString : ULongLong
    function : ULongLong
    ordinal : ULongLong
    addressOfData : ULongLong
  end

  struct IMAGE_THUNK_DATA64
    u1 : IMAGE_THUNK_DATA64_u1
  end

  IMAGE_ORDINAL_FLAG64 = 0x8000000000000000_u64

  alias IMAGE_NT_HEADERS = IMAGE_NT_HEADERS64
  alias IMAGE_THUNK_DATA = IMAGE_THUNK_DATA64
  IMAGE_ORDINAL_FLAG = IMAGE_ORDINAL_FLAG64
end
