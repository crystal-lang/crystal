require "./config"

module Crystal
  struct CrystalPath
    DEFAULT_PATH = ENV["CRYSTAL_PATH"]? || Crystal::Config::PATH

    def initialize(path = DEFAULT_PATH)
      @crystal_path = path.split ':'
    end

    def find(filename, relative_to = nil)
      relative_to = File.dirname(relative_to) if relative_to.is_a?(String)
      if filename.starts_with? '.'
        result = find_in_path_relative_to_dir(filename, relative_to)
      else
        result = find_in_crystal_path(filename, relative_to)
      end
      result = [result] if result.is_a?(String)
      result
    end

    private def find_in_path_relative_to_dir(filename, relative_to, check_crystal_path = true)
      if relative_to.is_a?(String)
        # Check if it's a wildcard.
        if filename.ends_with?("/*") || (recursive = filename.ends_with?("/**"))
          filename_dir_index = filename.rindex('/').not_nil!
          filename_dir = filename[0 .. filename_dir_index]
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

          # If it's a directory, we check if a .cr file with a name the same as the
          # directory basename exists, and we require that one.
          if Dir.exists?(relative_filename)
            basename = File.basename(relative_filename)
            absolute_filename = make_relative_unless_absolute("#{relative_filename}/#{basename}.cr")
            if File.exists?(absolute_filename)
              return absolute_filename
            end
          end
        end
      end

      if check_crystal_path
        find_in_crystal_path filename, relative_to
      else
        nil
      end
    end

    private def gather_dir_files(dir, files_accumulator, recursive)
      files = [] of String
      dirs = [] of String

      Dir.list(dir) do |filename, type|
        if type == Dir::Type::DIR
          if filename != "." && filename != ".." && recursive
            dirs << filename
          end
        else
          if filename.ends_with?(".cr")
            files << "#{dir}/#{filename}"
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
      filename = "#{Dir.working_directory}/#{filename}" unless filename.starts_with?('/')
      File.expand_path(filename)
    end

    private def find_in_crystal_path(filename, relative_to)
      @crystal_path.each do |path|
        required = find_in_path_relative_to_dir(filename, path, check_crystal_path: false)
        return required if required
      end

      if relative_to
        raise "can't find file '#{filename}' relative to '#{relative_to}'"
      else
        raise "can't find file '#{filename}'"
      end
    end
  end
end
