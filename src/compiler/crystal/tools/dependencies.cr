require "set"
require "colorize"
require "../syntax/ast"

class Crystal::Command
  private def dependencies
    dependency_printer = nil
    option_parser = parse_with_crystal_opts do |opts|
      opts.on("-f FORMAT", "--format FORMAT", "Format the output. Available options: flat, tree (default)") do |format|
        case format
        when "flat"
          dependency_printer = DependencyPrinter.new(STDOUT, flat: true)
        when "tree"
          dependency_printer = DependencyPrinter.new(STDOUT, flat: false)
        else
          abort "Invalid format: #{format}"
        end
      end
    end

    config = create_compiler "tool dependencies", no_codegen: true
    config.compiler.no_codegen = true

    config.compiler.dependency_printer = dependency_printer || DependencyPrinter.new(STDOUT)
    config.compile
  end
end

module Crystal
  class DependencyPrinter
    @indent = 0

    def initialize(@io : IO, @flat : Bool = false)
    end

    def enter_file(filename : String, unseen : Bool)
      unless unseen
        @indent += 1
        return
      end
      print_indent
      print_file(filename)

      @indent += 1
    end

    def leave_file
      @indent -= 1
    end

    private def print_indent
      return if @flat
      @io.print "  " * @indent.clamp(0..)
    end

    private def print_file(filename)
      @io.puts ::Path[filename].relative_to?(Dir.current) || filename
    end
  end
end
