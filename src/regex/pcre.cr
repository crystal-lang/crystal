@[Link("pcre")]
lib PCRE
  type Pcre = Void*
  fun compile = pcre_compile(pattern : UInt8*, options : Int32, errptr : UInt8**, erroffset : Int32*, tableptr : Void*) : Pcre
  fun exec = pcre_exec(code : Pcre, extra : Void*, subject : UInt8*, length : Int32, offset : Int32, options : Int32,
                ovector : Int32*, ovecsize : Int32) : Int32
  fun full_info = pcre_fullinfo(code : Pcre, extra : Void*, what : Int32, where : Int32*) : Int32
  fun get_named_substring = pcre_get_named_substring(code : Pcre, subject : UInt8*, ovector : Int32*, string_count : Int32, string_name : UInt8*, string_ptr : UInt8**) : Int32

  INFO_CAPTURECOUNT = 2

  $pcre_malloc : (UInt32 -> Void*)
end

PCRE.pcre_malloc = ->GC.malloc(UInt32)
