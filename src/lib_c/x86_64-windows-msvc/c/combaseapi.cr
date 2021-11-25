require "c/oleauto"

@[Link("ole32")]
lib LibC
  COINIT_MULTITHREADED = 0
  CLSCTX_INPROC_SERVER = 1

  alias REFIID = GUID*
  alias LCID = DWORD
  alias LPCOLESTR = WCHAR*

  alias IUnknown = Void # unused

  fun CoInitializeEx(pvReserved : Void*, dwCoInit : DWORD) : DWORD
  fun CoCreateInstance(rclsid : GUID*, pUnkOuter : IUnknown*, dwClsContext : DWORD, riid : REFIID, ppv : Void**) : DWORD
end
