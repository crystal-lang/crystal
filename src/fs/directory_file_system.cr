require "./file_system"

module FS
  class DirectoryFileSystem < FileSystem
    def initialize(@path)
    end

    def read(path)
      File.read scoped_file_name(path)
    end

    def entry?(path)
      if Dir.exists?(scoped_file_name(path))
        return create_entry(path)
      elsif File.exists?(scoped_file_name(path))
        return create_entry(path)
      else
        nil
      end
    end

    def entries(&block : Entry -> _)
      find_entries("", &block)
    end

    def find_entries(path, &block : Entry -> _)
      scoped = scoped_file_name(path)
      return unless Dir.exists?(scoped)

      Dir.foreach(scoped) do |entry|
        next if entry == "." || entry == ".."
        block.call(create_entry(combine(path, entry)))
      end
    end

    private def create_entry(entry)
      if File.directory?(scoped_file_name(entry))
        DirectoryEntry.new(self, entry)
      else
        FileEntry.new(self, entry)
      end
    end

    private def scoped_file_name(file_name)
      combine @path, file_name
    end
  end
end
