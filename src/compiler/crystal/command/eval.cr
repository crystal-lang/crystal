# Implementation of the `crystal eval` command

class Crystal::Command
  private def eval
    compiler = new_compiler
    parse_with_crystal_opts do |opts|
      opts.banner = "Usage: crystal eval [options] [source]\n\nOptions:"
      setup_simple_compiler_options compiler, opts
    end

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

    sources = [Compiler::Source.new("eval", program_source)]

    output_filename = Crystal.temp_executable "eval"

    compiler.compile sources, output_filename, combine_rpath: true
    execute output_filename, program_args, compiler
  end
end
