{% skip_file if flag?(:without_interpreter) %}

# Implementation of the `crystal repl` command

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
