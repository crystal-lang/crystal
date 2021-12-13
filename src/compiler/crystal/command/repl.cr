# Implementation of the `crystal repl` command
{% unless flag?(:without_interpreter) %}
  require "../interpreter/*"
{% end %}

class Crystal::Command
  private def repl
    repl = Repl.new

    if options.empty?
      repl.run
    else
      filename = options.shift
      unless File.file?(filename)
        error "File '#{filename}' doesn't exist"
      end

      repl.run_file(filename, options)
    end
  end
end
