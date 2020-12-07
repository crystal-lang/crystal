require "c/winnt"

lib LibC
  fun _wmkdir(dirname : WCHAR*) : Int
  fun _wrmdir(dirname : WCHAR*) : Int
end
