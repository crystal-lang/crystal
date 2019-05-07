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

  def self.error(msg, color, exit_code = 1, stderr = STDERR, leading_error = true)
    stderr.print "Error: ".colorize.toggle(color).red.bold if leading_error
    stderr.puts msg.colorize.toggle(color).bright
    exit(exit_code) if exit_code
  end

  def self.tempfile(basename)
    CacheDir.instance.join("crystal-run-#{basename}.tmp")
  end

  def self.with_line_numbers(
    source : String,
    highlight_line_number = nil,
    color = false,
    hide_after_highlight = false,
    join_lines = true
  )
    line_number_padding = (source.lines.size + 1).to_s.chars.size
    source_lines = source.lines
    if hide_after_highlight && highlight_line_number
      source_lines = source_lines[0..(highlight_line_number - 1)]
    end
    lines_with_numbers = source_lines.map_with_index do |line, i|
      line = line.to_s.chomp
      line_number = "%#{line_number_padding}d" % (i + 1)
      target = i + 1 == highlight_line_number
      if target
        if color
          " > #{line_number} | ".colorize.green.to_s + line.colorize.bold.to_s
        else
          " > #{line_number} | " + line
        end
      else
        if color
          " > #{line_number} | ".colorize.dim.to_s + line
        else
          "   #{line_number} | " + line
        end
      end
    end

    return lines_with_numbers unless join_lines
    lines_with_numbers.join '\n'
  end

  def self.normalize_path(path)
    path_start = ".#{File::SEPARATOR}"
    unless path.starts_with?(path_start) || path.starts_with?(File::SEPARATOR)
      path = path_start + path
    end
    path.rstrip(File::SEPARATOR)
  end
end
