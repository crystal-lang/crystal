require "set"
require "colorize"
require "../syntax/ast"

class Crystal::Command
  private def dependencies
    config = create_compiler "tool dependencies", no_codegen: true, dependencies: true

    dependency_printer = DependencyPrinter.new(STDOUT, flat: config.output_format == "flat")
    dependency_printer.includes.concat config.includes.map { |path| ::Path[path].expand.to_s }
    dependency_printer.excludes.concat config.excludes.map { |path| ::Path[path].expand.to_s }
    config.compiler.dependency_printer = dependency_printer

    config.compiler.top_level_semantic config.sources
  end
end

module Crystal
  class DependencyPrinter
    @depth = 0
    @filter_depth = Int32::MAX

    property includes = [] of String
    property excludes = [] of String

    getter default_paths : Array(::Path) = CrystalPath.default_paths.map { |path| ::Path[path].expand }

    def initialize(@io : IO, @flat : Bool = false)
    end

    def enter_file(filename : String, unseen : Bool)
      if @depth <= @filter_depth
        filter = filter?(filename)
        if filter
          @filter_depth = @depth
        else
          @filter_depth = Int32::MAX
        end

        print_indent
        print_file(filename)
        if unseen
          @io.print " (filtered)" if filter
        else
          @io.print " (duplicate skipped)"
        end
        @io.puts
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
      @io.print ::Path[filename].relative_to?(Dir.current) || filename
    end

    private def filter?(filename)
      paths = ::Path[filename].parents
      paths << ::Path[filename]

      return false if match_patterns?(includes, paths)

      return true if default_paths.any? { |path| paths.includes?(path) }

      match_patterns?(excludes, paths)
    end

    private def match_patterns?(patterns, paths)
      patterns.any? { |pattern| paths.any? { |path| File.match?(pattern, path) } }
    end
  end
end
