module FileUtils
  extend self

  # Changes the current working directory of the process to the given string *path*.
  # Alias of Dir.cd.
  # ```
  # FileUtils.cd("to/directory")
  # ```
  def cd(path : String)
    Dir.cd(path)
  end

  # Changes the current working firectory of the process to the given string *path*
  # and invoked the block, restoring the original working directory when the block exits.
  # Alias of Dir.cd with block.
  # ```
  # FileUtils.cd("to/directory") { puts "Do something useful here!" }
  # ```
  def cd(path : String)
    Dir.cd(path) { yield }
  end

  # Compares two files *filename1* to *filename2* to determine if they are identical.
  # Returns true if content are the same, false otherwise.
  # ```
  # FileUtils.cmp("foo.cr", "bar.cr")
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
  # Returns true if content are the same, false otherwise.
  # ```
  # FileUtils.cmp(stream1 : IO, stream2 : IO)
  # ```
  def cmp(stream1 : IO, stream2 : IO)
    buf1 = uninitialized UInt8[1024]
    buf2 = uninitialized UInt8[1024]

    while true
      read1 = stream1.read buf1.to_slice
      read2 = stream2.read buf2.to_slice

      return false if read1 != read2
      return false if buf1.to_unsafe.memcmp(buf2.to_unsafe, read1) != 0
      return true if read1 == 0
    end
  end

  # Copies the file *src_path* to the file or directory *dest*.
  # If *dest* is a directory, a file with the same basename as *src_path* is created in *dest*
  # Permission bits are copied too.
  # ```
  # FileUtils.cp("file_utils.cr", "file_utils_copy.cr")
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
  # ```
  # FileUtils.cp({"cgi.cr", "complex.cr", "date.cr"}, "files")
  # ```
  def cp(srcs : Enumerable(String), dest : String)
    raise ArgumentError.new("no such directory : #{dest}") unless Dir.exists?(dest)
    srcs.each do |src|
      cp(src, dest)
    end
  end

  # Copies a file or directory *src_path* to *dest_path*
  # If *src_path* is a directory, this method copies all its contents recursively
  # ```
  # FileUtils.cp_r("src_dir", "src_dir_copy")
  # ```
  def cp_r(src_path : String, dest_path : String)
    if Dir.exists?(src_path)
      Dir.mkdir(dest_path)
      Dir.open(src_path) do |dir|
        dir.each do |entry|
          if entry != "." && entry != ".."
            src = File.join(src_path, entry)
            dest = File.join(dest_path, entry)
            cp_r(src, dest)
          end
        end
      end
    else
      cp(src_path, dest_path)
    end
  end

  # Creates a new directory at the given *path*. The linux-style permission *mode*
  # can be specified, with a default of 777 (0o777).
  # Alias of Dir.mkdir
  # ```
  # FileUtils.mkdir("foo")
  # ```
  def mkdir(path : String, mode = 0o777) : Nil
    Dir.mkdir(path, mode)
  end

  # Creates a new directory at the given *paths*. The linux-style permission *mode*
  # can be specified, with a default of 777 (0o777).
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
  # Alias of Dir.mkdir_p
  # ```
  # FileUtils.mkdir_p("foo")
  # ```
  def mkdir_p(path : String, mode = 0o777) : Nil
    Dir.mkdir_p(path, mode)
  end

  # Creates a new directory at the given *paths*, including any non-existing
  # intermediate directories. The linux-style permission *mode* can be specified,
  # with a default of 777 (0o777).
  # ```
  # FileUtils.mkdir_p(["foo", "bar"])
  # ```
  def mkdir_p(paths : Enumerable(String), mode = 0o777) : Nil
    paths.each do |path|
      Dir.mkdir_p(path, mode)
    end
  end

  # Moves *src_path* to *dest_path*.
  # Alias of File.rename
  # ```
  # FileUtils.mv("afile", "afile.cr")
  # ```
  def mv(src_path : String, dest_path : String) : Nil
    File.rename(src_path, dest_path)
  end

  # Moves every *srcs* to *dest*.
  # ```
  # FileUtils.mv(["afile", "foo", "bar"], "src")
  # ```
  def mv(srcs : Enumerable(String), dest : String) : Nil
    raise ArgumentError.new("no such directory : #{dest}") unless Dir.exists?(dest)
    srcs.each do |src|
      begin
        mv(src, File.join(dest, File.basename(src)))
      rescue Errno
      end
    end
  end

  # Returns the current working directory.
  # Alias of Dir.current
  # ```
  # FileUtils.pwd
  # ```
  def pwd : String
    Dir.current
  end

  # Deletes the *path* file given.
  # Alias of File.delete
  # ```
  # FileUtils.rm("afile.cr")
  # ```
  def rm(path : String) : Nil
    File.delete(path)
  end

  # Deletes all *paths* file given.
  # ```
  # FileUtils.rm(["afile.cr", "bfile.cr"])
  # ```
  def rm(paths : Enumerable(String)) : Nil
    paths.each do |path|
      File.delete(path)
    end
  end

  # Deletes a file or directory *path*
  # If *path* is a directory, this method removes all its contents recursively
  # ```
  # FileUtils.rm_r("dir")
  # FileUtils.rm_r("file.cr")
  # ```
  def rm_r(path : String) : Nil
    if Dir.exists?(path) && !File.symlink?(path)
      Dir.open(path) do |dir|
        dir.each do |entry|
          if entry != "." && entry != ".."
            src = File.join(path, entry)
            rm_r(src)
          end
        end
      end
      Dir.rmdir(path)
    else
      File.delete(path)
    end
  end

  # Deletes a list of files or directories *paths*
  # If one path is a directory, this method removes all its contents recursively
  # ```
  # FileUtils.rm_r(["dir", "file.cr"])
  # ```
  def rm_r(paths : Enumerable(String)) : Nil
    paths.each do |path|
      rm_r(path)
    end
  end

  # Deletes a file or directory *path*
  # If *path* is a directory, this method removes all its contents recursively
  # Ignore all errors.
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

  # Deletes a list of files or directories *paths*
  # If one path is a directory, this method removes all its contents recursively
  # Ignore all errors.
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
  # Alias of Dir.rmdir
  # ```
  # FileUtils.rmdir("dir")
  # ```
  def rmdir(path : String) : Nil
    Dir.rmdir(path)
  end

  # Removes all directories at the given *paths*.
  # ```
  # FileUtils.rmdir(["dir1", "dir2", "dir3"])
  def rmdir(paths : Enumerable(String)) : Nil
    paths.each do |path|
      Dir.rmdir(path)
    end
  end
end
