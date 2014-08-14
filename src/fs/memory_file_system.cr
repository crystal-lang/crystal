require "./file_system"

module FS
  module MemoryFileContainer
    def add_directory(name)
      builder.add_directory(name)
    end

    def add_directory(name)
      add_directory(name).tap do |entry|
        yield entry
      end
    end

    def add_file(name, content)
      builder.add_file(name, content)
    end
  end

  class MemoryFileSystem < FileSystem
    def initialize
      @data = {} of String => MemoryDirectoryEntry | MemoryFileEntry
    end

    def builder
      @builder ||= MemoryFileSystemBuilder.new(self, "", @data)
    end

    include MemoryFileContainer

    def entries(&block : Entry -> U)
      # find_entries("", &block)
      @data.each_value do |entry|
        block.call entry
      end
    end

    def entry?(path)
      memory_entry_for_path(path)
    end

    def find_entries(path, &block : Entry -> U)
      entry = memory_entry_for_path(path)
      if entry.is_a? MemoryDirectoryEntry
        entry.data.each do |key, value|
          block.call value
        end
      end
    end

    def read(path)
      entry = memory_entry_for_path(path)
      if entry.is_a? MemoryFileEntry
        entry.content
      end
    end

    private def memory_entry_for_path(path)
      current = nil
      current_entries = @data

      path.split('/').each do |part|
        unless current_entries
          # raise "invalid entry #{path}"
          return nil
        else
          current = current_entries[part]?
          if current.is_a? MemoryDirectoryEntry
            current_entries = current.data
          else
            current_entries = nil
          end
        end
      end

      unless current
        # raise "invalid entry #{path}"
        return nil
      else
        current
      end
    end
  end

  class MemoryFileSystemBuilder
    def initialize(@fs, @prefix, @data)
    end

    def add_file(name, content)
      @data[name] = MemoryFileEntry.new(@fs, @fs.combine(@prefix, name)).tap do |entry|
        entry.content = content
      end
    end

    def add_directory(name)
      @data[name] = entry = MemoryDirectoryEntry.new(@fs, @fs.combine(@prefix, name))
    end
  end

  class MemoryDirectoryEntry < DirectoryEntry
    property data

    def initialize(fs, path)
      super
      @data = {} of String => MemoryDirectoryEntry | MemoryFileEntry
    end

    def builder
      @builder ||= MemoryFileSystemBuilder.new(@fs, @path, @data)
    end

    include MemoryFileContainer
  end

  class MemoryFileEntry < FileEntry
    property content
  end
end
