@[Link("pcre")]
lib LibPCRE
  alias Int = LibC::Int

  type Pcre = Void*
  type PcreExtra = Void*
  fun compile = pcre_compile(pattern : UInt8*, options : Int, errptr : UInt8**, erroffset : Int*, tableptr : Void*) : Pcre
  fun study = pcre_study(code : Pcre, options : Int, errptr : UInt8**) : PcreExtra
  fun exec = pcre_exec(code : Pcre, extra : PcreExtra, subject : UInt8*, length : Int, offset : Int, options : Int,
                       ovector : Int*, ovecsize : Int) : Int32
  fun full_info = pcre_fullinfo(code : Pcre, extra : PcreExtra, what : Int, where : Int32*) : Int
  fun get_stringnumber = pcre_get_stringnumber(code : Pcre, string_name : UInt8*) : Int
  fun get_stringtable_entries = pcre_get_stringtable_entries(code : Pcre, name : UInt8*, first : UInt8**, last : UInt8**) : Int

  INFO_CAPTURECOUNT  = 2
  INFO_NAMEENTRYSIZE = 7
  INFO_NAMECOUNT     = 8
  INFO_NAMETABLE     = 9

  alias Malloc = LibC::SizeT -> Void*
  alias Free = Void* ->

  $pcre_malloc : Malloc
  $pcre_free : Free
end

LibPCRE.pcre_malloc = ->GC.malloc(LibC::SizeT)
LibPCRE.pcre_free = ->GC.free(Void*)
