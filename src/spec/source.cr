module Spec
  # :nodoc:
  def self.lines_cache
    @@lines_cache ||= {} of String => Array(String)
  end

  # :nodoc:
  def self.read_line(file, line)
    return nil unless File.file?(file)

    lines = lines_cache[file] ||= File.read_lines(file)
    lines[line - 1]?
  end

  # :nodoc:
  def self.relative_file(file)
    cwd = Dir.current
    if file.starts_with?(cwd)
      file = file[cwd.size..-1]
      file = file[1..-1] if file.starts_with?('/')
    end
    file
  end
end
