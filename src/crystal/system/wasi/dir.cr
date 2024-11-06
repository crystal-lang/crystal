require "./wasi"

module Crystal::System::Dir
  private class DirHandle
    property fd : LibWasi::Fd
    property buf = Bytes.new(4096)
    property pos = 4096u32
    property end_pos = 4096u32
    property cookie = 0u64

    def initialize(@fd)
    end

    def fill_buffer(path)
      err = LibWasi.fd_readdir(@fd, @buf, @buf.size, @cookie, pointerof(@end_pos))
      raise ::File::Error.from_os_error("Error reading directory entries", err, file: path) unless err.success?
      @pos = 0
    end
  end

  def self.open(path : String) : DirHandle
    parent_fd, relative_path = Wasi.find_path_preopen(path)

    err = LibWasi.path_open(parent_fd, LibWasi::LookupFlags::SymlinkFollow, relative_path, LibWasi::OpenFlags::Directory, LibWasi::Rights::FdReaddir, LibWasi::Rights::None, LibWasi::FdFlags::None, out fd)
    raise ::File::Error.from_os_error("Error opening directory", err, file: path) unless err.success?

    DirHandle.new(fd)
  end

  def self.next_entry(dir, path) : Entry?
    if dir.end_pos < dir.buf.size && dir.pos >= dir.end_pos
      return nil
    end

    if dir.pos + sizeof(LibWasi::DirEnt) > dir.buf.size
      dir.fill_buffer(path)
    end

    dirent = Pointer(LibWasi::DirEnt).new(dir.buf.to_unsafe.address + dir.pos).value

    if dir.pos + sizeof(LibWasi::DirEnt) + dirent.d_namlen > dir.buf.size
      if dir.pos == 0
        dir.buf = Bytes.new(dir.buf.size * 2)
      end
      dir.fill_buffer(path)
      return next_entry(dir, path)
    end

    name = String.new(dir.buf[dir.pos + sizeof(LibWasi::DirEnt), dirent.d_namlen])
    dir.pos += sizeof(LibWasi::DirEnt) + dirent.d_namlen
    dir.cookie = dirent.d_next

    is_dir = case dirent.d_type
             when .directory?                then true
             when .unknown?, .symbolic_link? then nil
             else                                 false
             end

    Entry.new(name, is_dir, false)
  end

  def self.rewind(dir) : Nil
    dir.cookie = 0
    dir.end_pos = dir.pos = dir.buf.size.to_u32
  end

  def self.info(dir, path) : ::File::Info
    Crystal::System::FileDescriptor.system_info dir.fd
  end

  def self.close(dir, path) : Nil
    err = LibWasi.fd_close(dir.fd)
    raise ::File::Error.from_os_error("Error closing directory", err, file: path) unless err.success?
  end

  def self.current : String
    unless dir = LibC.getcwd(nil, 0)
      raise ::File::Error.from_errno("Error getting current directory", file: "./")
    end

    dir_str = String.new(dir)
    LibC.free(dir.as(Void*))
    dir_str
  end

  def self.current=(path : String)
    if LibC.chdir(path.check_no_null_byte) != 0
      raise ::File::Error.from_errno("Error while changing directory", file: path)
    end

    path
  end

  def self.tempdir
    tmpdir = ENV["TMPDIR"]? || "/tmp"
    tmpdir.rchop(::File::SEPARATOR)
  end

  def self.create(path : String, mode : Int32) : Nil
    if LibC.mkdir(path.check_no_null_byte, mode) == -1
      raise ::File::Error.from_errno("Unable to create directory", file: path)
    end
  end

  def self.delete(path : String, raise_on_missing : Bool) : Bool
    return true if LibC.rmdir(path.check_no_null_byte) == 0

    if !raise_on_missing && Errno.value == Errno::ENOENT
      false
    else
      raise ::File::Error.from_errno("Unable to remove directory", file: path)
    end
  end
end
