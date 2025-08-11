lib LibC
  FLS_OUT_OF_INDEXES = 0xFFFFFFFF_u32

  alias FLS_CALLBACK_FUNCTION = Proc(Void*, Nil)

  fun FlsAlloc(FLS_CALLBACK_FUNCTION) : DWORD
  fun FlsFree(DWORD) : BOOL
  fun FlsGetValue(DWORD) : Void*
  fun FlsSetValue(DWORD, Void*) : BOOL
end
