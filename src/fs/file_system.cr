require "./base"

module FS
  abstract class FileSystem
    include FileContainer

    def combine(a, b)
      if b.empty?
        a
      elsif a.empty?
        b
      else
        "#{a}/#{b}"
      end
    end

    # read whole content of file in a string
    def read(path)
      raise "subclass responsibility"
    end

    # create Entry corresponding that corresponds to the specified
    # relative path to the file system
    def entry(path)
      raise "subclass responsibility"
    end

    # enumerate top level entries of file system
    def entries(&block : Entry+ -> U)
      raise "subclass responsibility"
    end

    collect_alias_method "entries", "Entry+"

    # enumerate entries below specified relative path to the file system
    def find_entries(path, &block : Entry+ -> U)
      raise "subclass responsibility"
    end

    collect_alias_method "find_entries(path)", "Entry+"

    def exists?(path)
      find_entries(path).count == 1
    end
  end
end
