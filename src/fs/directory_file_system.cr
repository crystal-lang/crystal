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
        return create_entry(path, Dir::Type::DIR)
      elsif File.exists?(scoped_file_name(path))
        return create_entry(path, Dir::Type::REG)
      else
        nil
      end
    end

    def entries(&block : Entry -> U)
      find_entries("", &block)
    end

    def find_entries(path, &block : Entry -> U)
      return unless Dir.exists?(scoped_file_name(path))

      Dir.list(scoped_file_name(path)) do |entry, type|
        next if entry == "." || entry == ".."
        block.call(create_entry(combine(path, entry), type))
      end
    end

    private def create_entry(entry, type)
      case type
      when Dir::Type::DIR
        DirectoryEntry.new(self, entry)
      # else
      when Dir::Type::REG
        FileEntry.new(self, entry)
      else
        raise "not implemented"
      end
    end

    private def scoped_file_name(file_name)
      combine @path, file_name
    end
  end
end
