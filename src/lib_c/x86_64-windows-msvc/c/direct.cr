require "c/winnt"

lib LibC
  # unused
  fun _wmkdir(dirname : WCHAR*) : Int
  fun _wrmdir(dirname : WCHAR*) : Int
end
