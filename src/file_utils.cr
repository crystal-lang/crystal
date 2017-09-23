module FileUtils
  extend self

  # Changes the current working directory of the process to the given string *path*.
  #
  # ```
  # require "file_utils"
  #
  # FileUtils.cd("/tmp")
  # ```
  #
  # NOTE: Alias of `Dir.cd`
  def cd(path : String)
    Dir.cd(path)
  end

  # Changes the current working directory of the process to the given string *path*
  # and invoked the block, restoring the original working directory when the block exits.
  #
  # ```
  # FileUtils.cd("/tmp") { Dir.current } # => "/tmp"
  # ```
  #
  # NOTE: Alias of `Dir.cd` with block
  def cd(path : String)
    Dir.cd(path) { yield }
  end

  # Compares two files *filename1* to *filename2* to determine if they are identical.
  # Returns `true` if content are the same, `false` otherwise.
  #
  # ```
  # File.write("file.cr", "1")
  # File.write("bar.cr", "1")
  # FileUtils.cmp("file.cr", "bar.cr") # => true
  # ```
  def cmp(filename1 : String, filename2 : String)
    return false unless File.size(filename1) == File.size(filename2)

    File.open(filename1, "rb") do |file1|
      File.open(filename2, "rb") do |file2|
        cmp(file1, file2)
      end
    end
  end

  # Compares two streams *stream1* to *stream2* to determine if they are identical.
  # Returns `true` if content are the same, `false` otherwise.
  #
  # ```
  # File.write("afile", "123")
  # stream1 = File.open("afile")
  # stream2 = IO::Memory.new("123")
  # FileUtils.cmp(stream1, stream2) # => true
  # ```
  def cmp(stream1 : IO, stream2 : IO)
    buf1 = uninitialized UInt8[1024]
    buf2 = uninitialized UInt8[1024]

    while true
      read1 = stream1.read(buf1.to_slice)
      read2 = stream2.read_fully?(buf2.to_slice[0, read1])
      return false unless read2

      return false if buf1.to_unsafe.memcmp(buf2.to_unsafe, read1) != 0
      return true if read1 == 0
    end
  end

  # Attempts to set the access and modification times of the file named
  # in the *path* parameter to the value given in *time*.
  #
  # If the file does not exist, it will be created.
  #
  # ```
  # FileUtils.touch("afile.cr")
  # ```
  #
  # NOTE: Alias of `File.touch`
  def touch(path : String, time : Time = Time.now)
    File.touch(path, time)
  end

  # Attempts to set the access and modification times of each file given
  # in the *paths* parameter to the value given in *time*.
  #
  # If the file does not exist, it will be created.
  #
  # ```
  # FileUtils.touch(["foo", "bar"])
  # ```
  def touch(paths : Enumerable(String), time : Time = Time.now)
    paths.each do |path|
      touch(path, time)
    end
  end

  # Copies the file *src_path* to the file or directory *dest*.
  # If *dest* is a directory, a file with the same basename as *src_path* is created in *dest*
  # Permission bits are copied too.
  #
  # ```
  # File.chmod("afile", 0o600)
  # FileUtils.cp("afile", "afile_copy")
  # File.stat("afile_copy").perm # => 0o600
  # ```
  def cp(src_path : String, dest : String)
    File.open(src_path) do |s|
      dest += File::SEPARATOR + File.basename(src_path) if Dir.exists?(dest)
      File.open(dest, "wb", s.stat.mode) do |d|
        IO.copy(s, d)
      end
    end
  end

  # Copies a list of files *src* to *dest*.
  # *dest* must be an existing directory.
  #
  # ```
  # Dir.mkdir("files")
  # FileUtils.cp({"bar.cr", "afile"}, "files")
  # ```
  def cp(srcs : Enumerable(String), dest : String)
    raise ArgumentError.new("No such directory : #{dest}") unless Dir.exists?(dest)
    srcs.each do |src|
      cp(src, dest)
    end
  end

  # Copies a file or directory *src_path* to *dest_path*.
  # If *src_path* is a directory, this method copies all its contents recursively.
  #
  # ```
  # FileUtils.cp_r("files", "dir")
  # ```
  def cp_r(src_path : String, dest_path : String)
    if Dir.exists?(src_path)
      Dir.mkdir(dest_path)
      Dir.each_child(src_path) do |entry|
        src = File.join(src_path, entry)
        dest = File.join(dest_path, entry)
        cp_r(src, dest)
      end
    else
      cp(src_path, dest_path)
    end
  end

  # Creates a new directory at the given *path*. The linux-style permission *mode*
  # can be specified, with a default of 777 (0o777).
  #
  # ```
  # FileUtils.mkdir("src")
  # ```
  #
  # NOTE: Alias of `Dir.mkdir`
  def mkdir(path : String, mode = 0o777) : Nil
    Dir.mkdir(path, mode)
  end

  # Creates a new directory at the given *paths*. The linux-style permission *mode*
  # can be specified, with a default of 777 (0o777).
  #
  # ```
  # FileUtils.mkdir(["foo", "bar"])
  # ```
  def mkdir(paths : Enumerable(String), mode = 0o777) : Nil
    paths.each do |path|
      Dir.mkdir(path, mode)
    end
  end

  # Creates a new directory at the given *path*, including any non-existing
  # intermediate directories. The linux-style permission *mode* can be specified,
  # with a default of 777 (0o777).
  #
  # ```
  # FileUtils.mkdir_p("foo")
  # ```
  #
  # NOTE: Alias of `Dir.mkdir_p`
  def mkdir_p(path : String, mode = 0o777) : Nil
    Dir.mkdir_p(path, mode)
  end

  # Creates a new directory at the given *paths*, including any non-existing
  # intermediate directories. The linux-style permission *mode* can be specified,
  # with a default of 777 (0o777).
  #
  # ```
  # FileUtils.mkdir_p(["foo", "bar", "baz", "dir1", "dir2", "dir3"])
  # ```
  def mkdir_p(paths : Enumerable(String), mode = 0o777) : Nil
    paths.each do |path|
      Dir.mkdir_p(path, mode)
    end
  end

  # Moves *src_path* to *dest_path*.
  #
  # ```
  # FileUtils.mv("afile", "afile.cr")
  # ```
  #
  # NOTE: Alias of `File.rename`
  def mv(src_path : String, dest_path : String) : Nil
    File.rename(src_path, dest_path)
  end

  # Moves every *srcs* to *dest*.
  #
  # ```
  # FileUtils.mv(["foo", "bar"], "src")
  # ```
  def mv(srcs : Enumerable(String), dest : String) : Nil
    raise ArgumentError.new("No such directory : #{dest}") unless Dir.exists?(dest)
    srcs.each do |src|
      begin
        mv(src, File.join(dest, File.basename(src)))
      rescue Errno
      end
    end
  end

  # Returns the current working directory.
  #
  # ```
  # FileUtils.pwd
  # ```
  #
  # NOTE: Alias of `Dir.current`
  def pwd : String
    Dir.current
  end

  # Deletes the *path* file given.
  #
  # ```
  # FileUtils.rm("afile.cr")
  # ```
  #
  # NOTE: Alias of `File.delete`
  def rm(path : String) : Nil
    File.delete(path)
  end

  # Deletes all *paths* file given.
  #
  # ```
  # FileUtils.rm(["dir/afile", "afile_copy"])
  # ```
  def rm(paths : Enumerable(String)) : Nil
    paths.each do |path|
      File.delete(path)
    end
  end

  # Deletes a file or directory *path*.
  # If *path* is a directory, this method removes all its contents recursively.
  #
  # ```
  # FileUtils.rm_r("dir")
  # FileUtils.rm_r("file.cr")
  # ```
  def rm_r(path : String) : Nil
    if Dir.exists?(path) && !File.symlink?(path)
      Dir.each_child(path) do |entry|
        src = File.join(path, entry)
        rm_r(src)
      end
      Dir.rmdir(path)
    else
      File.delete(path)
    end
  end

  # Deletes a list of files or directories *paths*.
  # If one path is a directory, this method removes all its contents recursively.
  #
  # ```
  # FileUtils.rm_r(["files", "bar.cr"])
  # ```
  def rm_r(paths : Enumerable(String)) : Nil
    paths.each do |path|
      rm_r(path)
    end
  end

  # Deletes a file or directory *path*.
  # If *path* is a directory, this method removes all its contents recursively.
  # Ignore all errors.
  #
  # ```
  # FileUtils.rm_rf("dir")
  # FileUtils.rm_rf("file.cr")
  # FileUtils.rm_rf("non_existent_file")
  # ```
  def rm_rf(path : String) : Nil
    begin
      rm_r(path)
    rescue Errno
    end
  end

  # Deletes a list of files or directories *paths*.
  # If one path is a directory, this method removes all its contents recursively.
  # Ignore all errors.
  #
  # ```
  # FileUtils.rm_rf(["dir", "file.cr", "non_existent_file"])
  # ```
  def rm_rf(paths : Enumerable(String)) : Nil
    paths.each do |path|
      begin
        rm_r(path)
      rescue Errno
      end
    end
  end

  # Removes the directory at the given *path*.
  #
  # ```
  # FileUtils.rmdir("baz")
  # ```
  #
  # NOTE: Alias of `Dir.rmdir`
  def rmdir(path : String) : Nil
    Dir.rmdir(path)
  end

  # Removes all directories at the given *paths*.
  #
  # ```
  # FileUtils.rmdir(["dir1", "dir2", "dir3"])
  # ```
  def rmdir(paths : Enumerable(String)) : Nil
    paths.each do |path|
      Dir.rmdir(path)
    end
  end
end
