@[Link("pcre")]
lib LibPCRE
  alias Int = LibC::Int

  type Pcre = Void*

  struct Extra
    flags : LibC::ULong
    study_data : Void*
    match_limit : LibC::ULong
    callout_data : Void*
    tables : LibC::UChar*
    match_limit_recursion : LibC::ULong
    mark : LibC::UChar**
    executable_jit : Void*
  end

  fun compile = pcre_compile(pattern : UInt8*, options : Int, errptr : UInt8**, erroffset : Int*, tableptr : Void*) : Pcre
  fun exec = pcre_exec(code : Pcre, extra : Extra*, subject : UInt8*, length : Int, offset : Int, options : Int, ovector : Int*, ovecsize : Int) : Int32
  fun study = pcre_study(code : Pcre, options : Int, errptr : UInt8**) : Extra*
  fun free_study = pcre_free_study(extra : Extra*) : Void
  fun full_info = pcre_fullinfo(code : Pcre, extra : Extra*, what : Int, where : Int32*) : Int
  fun get_stringnumber = pcre_get_stringnumber(code : Pcre, string_name : UInt8*) : Int
  fun get_stringtable_entries = pcre_get_stringtable_entries(code : Pcre, name : UInt8*, first : UInt8**, last : UInt8**) : Int

  INFO_CAPTURECOUNT  = 2
  INFO_NAMEENTRYSIZE = 7
  INFO_NAMECOUNT     = 8
  INFO_NAMETABLE     = 9

  EXTRA_MARK = 0x0020

  alias Malloc = LibC::SizeT -> Void*
  alias Free = Void* ->

  $pcre_malloc : Malloc
  $pcre_free : Free
end

LibPCRE.pcre_malloc = ->GC.malloc(LibC::SizeT)
LibPCRE.pcre_free = ->GC.free(Void*)
