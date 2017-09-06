require "./config"

module Crystal
  struct CrystalPath
    class Error < Exception
    end

    def self.default_path
      ENV["CRYSTAL_PATH"]? || Crystal::Config.path
    end

    @crystal_path : Array(String)

    def initialize(path = CrystalPath.default_path, target_triple = Crystal::Config.default_target_triple)
      @crystal_path = path.split(':').reject &.empty?
      add_target_path(target_triple)
    end

    private def add_target_path(target_triple = Crystal::Config.default_target_triple)
      triple = target_triple.split('-')
      triple.delete(triple[1]) if triple.size == 4 # skip vendor

      case triple[0]
      when "i386", "i486", "i586"
        triple[0] = "i686"
      when .starts_with?("armv8")
        triple[0] = "aarch64"
      when .starts_with?("arm")
        triple[0] = "arm"
      end

      target = if triple.any?(&.includes?("macosx")) || triple.any?(&.includes?("darwin"))
                 {triple[0], "macosx", "darwin"}.join('-')
               elsif triple.any?(&.includes?("freebsd"))
                 {triple[0], triple[1], "freebsd"}.join('-')
               elsif triple.any?(&.includes?("openbsd"))
                 {triple[0], triple[1], "openbsd"}.join('-')
               else
                 triple.join('-')
               end

      @crystal_path.each do |path|
        _path = File.join(path, "lib_c", target)
        if Dir.exists?(_path)
          @crystal_path << _path unless @crystal_path.includes?(_path)
          return
        end
      end
    end

    def find(filename, relative_to = nil) : Array(String)?
      relative_to = File.dirname(relative_to) if relative_to.is_a?(String)

      if filename.starts_with? '.'
        result = find_in_path_relative_to_dir(filename, relative_to)
      else
        result = find_in_crystal_path(filename)
      end

      cant_find_file filename, relative_to unless result

      result = [result] if result.is_a?(String)
      result
    end

    private def find_in_path_relative_to_dir(filename, relative_to)
      if relative_to.is_a?(String)
        # Check if it's a wildcard.
        if filename.ends_with?("/*") || (recursive = filename.ends_with?("/**"))
          filename_dir_index = filename.rindex('/').not_nil!
          filename_dir = filename[0..filename_dir_index]
          relative_dir = "#{relative_to}/#{filename_dir}"
          if File.exists?(relative_dir)
            files = [] of String
            gather_dir_files(relative_dir, files, recursive)
            return files
          end
        else
          relative_filename = "#{relative_to}/#{filename}"

          # Check if .cr file exists.
          relative_filename_cr = relative_filename.ends_with?(".cr") ? relative_filename : "#{relative_filename}.cr"
          if File.exists?(relative_filename_cr)
            return make_relative_unless_absolute relative_filename_cr
          end

          if slash_index = filename.index('/')
            # If it's "foo/bar/baz", check if "foo/src/bar/baz.cr" exists (for a shard, non-namespaced structure)
            before_slash, after_slash = filename.split('/', 2)
            absolute_filename = make_relative_unless_absolute("#{relative_to}/#{before_slash}/src/#{after_slash}.cr")
            return absolute_filename if File.exists?(absolute_filename)

            # Then check if "foo/src/foo/bar/baz.cr" exists (for a shard, namespaced structure)
            absolute_filename = make_relative_unless_absolute("#{relative_to}/#{before_slash}/src/#{before_slash}/#{after_slash}.cr")
            return absolute_filename if File.exists?(absolute_filename)

            # If it's "foo/bar/baz", check if "foo/bar/baz/baz.cr" exists (std, nested)
            basename = File.basename(relative_filename)
            absolute_filename = make_relative_unless_absolute("#{relative_to}/#{filename}/#{basename}.cr")
            return absolute_filename if File.exists?(absolute_filename)

            # If it's "foo/bar/baz", check if "foo/src/foo/bar/baz/baz.cr" exists (shard, non-namespaced, nested)
            absolute_filename = make_relative_unless_absolute("#{relative_to}/#{before_slash}/src/#{after_slash}/#{after_slash}.cr")
            return absolute_filename if File.exists?(absolute_filename)

            # If it's "foo/bar/baz", check if "foo/src/foo/bar/baz/baz.cr" exists (shard, namespaced, nested)
            absolute_filename = make_relative_unless_absolute("#{relative_to}/#{before_slash}/src/#{before_slash}/#{after_slash}/#{after_slash}.cr")
            return absolute_filename if File.exists?(absolute_filename)
          else
            basename = File.basename(relative_filename)

            # If it's "foo", check if "foo/foo.cr" exists (for the std, nested)
            absolute_filename = make_relative_unless_absolute("#{relative_filename}/#{basename}.cr")
            return absolute_filename if File.exists?(absolute_filename)

            # If it's "foo", check if "foo/src/foo.cr" exists (for a shard)
            absolute_filename = make_relative_unless_absolute("#{relative_filename}/src/#{basename}.cr")
            return absolute_filename if File.exists?(absolute_filename)
          end
        end
      end

      nil
    end

    private def gather_dir_files(dir, files_accumulator, recursive)
      files = [] of String
      dirs = [] of String

      Dir.each_child(dir) do |filename|
        full_name = "#{dir}/#{filename}"

        if File.directory?(full_name)
          if recursive
            dirs << filename
          end
        else
          if filename.ends_with?(".cr")
            files << full_name
          end
        end
      end

      files.sort!
      dirs.sort!

      files.each do |file|
        files_accumulator << File.expand_path(file)
      end

      dirs.each do |subdir|
        gather_dir_files("#{dir}/#{subdir}", files_accumulator, recursive)
      end
    end

    private def make_relative_unless_absolute(filename)
      filename = "#{Dir.current}/#{filename}" unless filename.starts_with?('/')
      File.expand_path(filename)
    end

    private def find_in_crystal_path(filename)
      @crystal_path.each do |path|
        required = find_in_path_relative_to_dir(filename, path)
        return required if required
      end

      nil
    end

    private def cant_find_file(filename, relative_to)
      if relative_to
        raise Error.new("can't find file '#{filename}' relative to '#{relative_to}'")
      else
        raise Error.new("can't find file '#{filename}'")
      end
    end
  end
end
