module Spec
  # :nodoc:
  def self.lines_cache
    @@lines_cache ||= {} of String => Array(String)
  end

  # :nodoc:
  def self.read_line(file, line)
    return nil unless File.file?(file)

    lines = lines_cache.put_if_absent(file) { File.read_lines(file) }
    lines[line - 1]?
  end
end
