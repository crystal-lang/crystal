require "./elf"

lib LibC
  struct DlPhdrInfo
    addr : Elf_Addr
    name : Char*
    phdr : Elf_Phdr*
    phnum : Elf_Half
    adds : ULongLong
    subs : ULongLong
    tls_modid : SizeT
    tls_data : Void*
  end

  alias DlPhdrCallback = (DlPhdrInfo*, LibC::SizeT, Void*) -> LibC::Int
  fun dl_iterate_phdr(callback : DlPhdrCallback, data : Void*)
end
