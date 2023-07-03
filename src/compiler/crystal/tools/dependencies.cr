require "set"
require "colorize"
require "../syntax/ast"

class Crystal::Command
  private def dependencies
    config = create_compiler "tool dependencies", no_codegen: true, dependencies: true

    config.compiler.dependency_printer = DependencyPrinter.new(STDOUT, flat: config.output_format == "flat")
    config.compiler.top_level_semantic config.sources
  end
end

module Crystal
  class DependencyPrinter
    @depth = 0

    def initialize(@io : IO, @flat : Bool = false)
    end

    def enter_file(filename : String, unseen : Bool)
      if unseen
        print_indent
        print_file(filename)
      end

      @depth += 1
    end

    def leave_file
      @depth -= 1
    end

    private def print_indent
      return if @flat
      @io.print "  " * @depth if @depth > 0
    end

    private def print_file(filename)
      @io.puts ::Path[filename].relative_to?(Dir.current) || filename
    end
  end
end
