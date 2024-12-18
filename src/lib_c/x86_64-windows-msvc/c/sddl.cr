require "c/winnt"

lib LibC
  fun ConvertSidToStringSidW(sid : SID*, stringSid : LPWSTR*) : BOOL
  fun ConvertStringSidToSidW(stringSid : LPWSTR, sid : SID**) : BOOL
end
