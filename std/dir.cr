lib C
  fun getcwd(buffer : Char*, size : Int32) : Char*
end

class Dir
  def self.working_directory
    dir = C.getcwd(nil, 0)
    String.from_cstr(dir)
  end
end