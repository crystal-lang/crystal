module FileUtils
  extend self

  def cmp(filename1 : String, filename2 : String)
    return false unless File.size(filename1) == File.size(filename2)

    File.open(filename1, "rb") do |file1|
      File.open(filename2, "rb") do |file2|
        cmp(file1, file2)
      end
    end
  end

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

  # Deletes a file or directory *path*
  # If *path* is a directory, this method removes all its contents recursively
  # ```
  # FileUtils.rm_r("dir")
  # FileUtils.rm_r("file.cr")
  # ```
  def rm_r(path : String)
    if Dir.exists?(path)
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
end
