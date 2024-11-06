require "c/libloaderapi"
require "c/winnt"

lib LibC
  alias RVA = DWORD

  struct ImgDelayDescr
    grAttrs : DWORD     # attributes
    rvaDLLName : RVA    # RVA to dll name
    rvaHmod : RVA       # RVA of module handle
    rvaIAT : RVA        # RVA of the IAT
    rvaINT : RVA        # RVA of the INT
    rvaBoundIAT : RVA   # RVA of the optional bound IAT
    rvaUnloadIAT : RVA  # RVA of optional copy of original IAT
    dwTimeStamp : DWORD # 0 if not bound, O.W. date/time stamp of DLL bound to (Old BIND)
  end

  DLAttrRva = 0x1

  union DelayLoadProc_union
    szProcName : LPSTR
    dwOrdinal : DWORD
  end

  struct DelayLoadProc
    fImportByName : BOOL
    union : DelayLoadProc_union
  end

  struct DelayLoadInfo
    cb : DWORD            # size of structure
    pidd : ImgDelayDescr* # raw form of data (everything is there)
    ppfn : FARPROC*       # points to address of function to load
    szDll : LPSTR         # name of dll
    dlp : DelayLoadProc   # name or ordinal of procedure
    hmodCur : HMODULE     # the hInstance of the library we have loaded
    pfnCur : FARPROC      # the actual function that will be called
    dwLastError : DWORD   # error received (if an error notification)
  end
end
