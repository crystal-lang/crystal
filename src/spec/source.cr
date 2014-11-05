module Spec
  def self.lines_cache
    @@lines_cache ||= {} of String => Array(String)
  end

  def self.read_line(file, line)
    return nil unless File.exists?(file)

    lines = lines_cache[file] ||= File.read_lines(file)
    lines[line - 1]?
  end

  def self.relative_file(file)
    cwd = Dir.working_directory
    if file.starts_with?(cwd)
      file = ".#{file[cwd.length .. -1]}"
    end
    file
  end
end
