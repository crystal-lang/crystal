macro collect_alias_method(method, type)
  #should be method.id ? since it may have params.
  def {{method.id}}
    res = [] of {{type.id}}
    {{method.id}} do |e|
      res << e
    end
    res
  end
end

module FS
  module FileContainer
    def files(&block : FileEntry+ -> U)
      entries do |e|
        block.call(e) if e.is_a?(FileEntry)
      end
    end
    collect_alias_method "files", "FileEntry"

    def dirs(&block : DirectoryEntry+ -> U)
      entries do |e|
        block.call(e) if e.is_a?(DirectoryEntry)
      end
    end
    collect_alias_method "dirs", "DirectoryEntry"

    def dir(path)
      res = entry(path)
      return res if res.is_a?(DirectoryEntry)
      raise "#{path} is not a directory"
    end

    def file(path)
      res = entry(path)
      return res if res.is_a?(FileEntry)
      raise "#{path} is not a file"
    end
  end

  class Entry
    def initialize(@fs : FileSystem, @path : String)
    end

    # the name of the file or directory
    def name
      File.basename(@path)
    end

    # the relative path from the filesystem
    # requesting this path to the filesystem
    # should get an equivalent entry
    def path
      @path
    end

    def file?
      false
    end

    def dir?
      false
    end
  end

  class FileEntry < Entry
    def file?
      true
    end

    def read
      @fs.read(path)
    end
  end

  class DirectoryEntry < Entry
    include FileContainer

    def dir?
      true
    end

    def open(file_name)
      @fs.open(scoped_file_name(file_name))
    end

    def entries(&block : Entry+ -> U)
      @fs.find_entries(scoped_file_name(""), &block)
    end

    collect_alias_method "entries", "Entry+"

    def entry(file_name)
      @fs.entry @fs.combine(path, file_name)
    end

    # private

    def scoped_file_name(file_name)
      @fs.combine path, file_name
    end
  end
end
