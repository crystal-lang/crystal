module Crystal
  def self.relative_filename(filename : String) : String
    if base_file = filename.lchop? Dir.current
      if file_prefix = base_file.lchop? '/'
        return file_prefix
      end
      return base_file
    end
    filename
  end

  def self.relative_filename(filename)
    filename
  end

  def self.error(msg, color, exit_code = 1, stderr = STDERR)
    stderr.print "Error: ".colorize.toggle(color).red.bold
    stderr.puts msg.colorize.toggle(color).bright
    exit(exit_code) if exit_code
  end

  def self.tempfile(basename)
    CacheDir.instance.join("crystal-run-#{basename}.tmp")
  end

  def self.with_line_numbers(source : String, highlight_line_number = nil, color = false)
    source.lines.map_with_index do |line, i|
      str = "#{"%4d" % (i + 1)}. #{line.to_s.chomp}"
      target = i + 1 == highlight_line_number
      if target
        if color
          str = ">".colorize.green.bold.to_s + str[1..-1].colorize.bold.to_s
        else
          str = ">" + str[1..-1]
        end
      end
      str
    end.join '\n'
  end

  def self.normalize_path(path)
    path_start = ".#{File::SEPARATOR}"
    unless path.starts_with?(path_start) || path.starts_with?(File::SEPARATOR)
      path = path_start + path
    end
    path.rstrip(File::SEPARATOR)
  end
end
