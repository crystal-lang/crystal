module Crystal
  def self.relative_filename(filename : String)
    dir = Dir.current
    if filename.starts_with?(dir)
      filename = filename[dir.size..-1]
      filename.lchop('/')
    else
      filename
    end
  end

  def self.relative_filename(filename)
    filename
  end

  def self.error(msg, exit_code = 1, stderr = STDERR)
    stderr.print "Error: ".colorize.red.bold
    stderr.puts msg.colorize.bright
    exit(exit_code) if exit_code
  end

  def self.tempfile(basename)
    CacheDir.instance.join("crystal-run-#{basename}.tmp")
  end

  def self.with_line_numbers(source : String, highlight_line_number = nil)
    String.build do |io|
      i = 0
      source.each_line do |line|
        i += 1
        if i == highlight_line_number
          io << ">".colorize.green.bold << "#{"%3d" % i}. #{line}".colorize.bold << '\n'
        else
          io.puts "#{"%4d" % i}. #{line}"
        end
      end
    end
  end
end
