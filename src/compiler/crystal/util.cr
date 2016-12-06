module Crystal
  def self.relative_filename(filename : String)
    dir = Dir.current
    if filename.starts_with?(dir)
      filename = filename[dir.size..-1]
      if filename.starts_with? '/'
        filename[1..-1]
      else
        filename
      end
    else
      filename
    end
  end

  def self.relative_filename(filename)
    filename
  end

  def self.error(msg, color, exit_code = 1, stderr = STDERR)
    stderr.print "Error: ".colorize.toggle(color).red.bold
    stderr.puts msg.colorize.toggle(color).bright
    exit(exit_code) if exit_code
  end

  def self.timing(label, stats, delay = false)
    if stats
      print "%-34s" % "#{label}:" unless delay
      time = Time.now
      value = yield
      elapsed_time = Time.now - time
      LibGC.get_heap_usage_safe(out heap_size, out free_bytes, out unmapped_bytes, out bytes_since_gc, out total_bytes)
      mb = heap_size / 1024.0 / 1024.0
      if delay
        puts "%-34s %s (%7.2fMB)" % {"#{label}:", elapsed_time, mb}
      else
        puts " %s (%7.2fMB)" % {elapsed_time, mb}
      end
      value
    else
      yield
    end
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
    end.join "\n"
  end
end
