# Implementation of the `crystal eval` command

class Crystal::Command
  private def eval
    if options.empty?
      program_source = STDIN.gets_to_end
      program_args = [] of String
    else
      double_dash_index = options.index("--")
      if double_dash_index
        program_source = options[0...double_dash_index].join " "
        program_args = options[double_dash_index + 1..-1]
      else
        program_source = options.join " "
        program_args = [] of String
      end
    end

    compiler = Compiler.new
    sources = [Compiler::Source.new("eval", program_source)]

    output_filename = Crystal.tempfile "eval"

    result = compiler.compile sources, output_filename
    execute output_filename, program_args
  end
end
