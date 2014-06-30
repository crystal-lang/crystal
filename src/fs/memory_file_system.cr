require "./file_system"

module FS
  module MemoryFileContainer
    def add_directory(name)
      builder.add_directory(name)
    end

    def add_directory(name)
      add_directory(name).tap do |mem_entry|
        yield mem_entry
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

    def entries(&block : Entry+ -> U)
      # find_entries("", &block)
      @data.each do |key, value|
        block.call value.entry
      end
    end

    def entry(path)
      memory_entry_for_path(path).entry
    end

    def find_entries(path, &block : Entry+ -> U)
      mem_entry = memory_entry_for_path(path)
      if mem_entry.is_a? MemoryDirectoryEntry
        mem_entry.data.each do |key, value|
          block.call value.entry
        end
      end
    end

    def read(path)
      mem_entry = memory_entry_for_path(path)
      if mem_entry.is_a? MemoryFileEntry
        mem_entry.content
      end
    end

    # private

    def memory_entry_for_path(path)
      current = nil
      current_entries = @data

      path.split('/').each do |part|
        unless current_entries
          raise "invalid entry #{path}"
        else
          current = current_entries[part]
          if current.is_a? MemoryDirectoryEntry
            current_entries = current.data
          else
            current_entries = nil
          end
        end
      end

      unless current
        raise "invalid entry #{path}"
      else
        current
      end
    end
  end

  class MemoryFileSystemBuilder
    def initialize(@fs, @prefix, @data)
    end

    def add_file(name, content)
      @data[name] = MemoryFileEntry.new(@fs, @fs.combine(@prefix, name), content)
    end

    def add_directory(name)
      @data[name] = entry = MemoryDirectoryEntry.new(@fs, @fs.combine(@prefix, name))
    end
  end

  class MemoryDirectoryEntry
    property data

    def initialize(@fs, @path)
      @data = {} of String => MemoryDirectoryEntry | MemoryFileEntry
    end

    def builder
      @builder ||= MemoryFileSystemBuilder.new(@fs, @path, @data)
    end

    include MemoryFileContainer

    def entry
      DirectoryEntry.new(@fs, @path)
    end
  end

  class MemoryFileEntry
    property path
    property content

    def initialize(@fs, @path, @content)
    end

    def entry
      FileEntry.new(@fs, @path)
    end
  end
end
