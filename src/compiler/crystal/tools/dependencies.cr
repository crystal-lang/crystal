require "set"
require "colorize"
require "../syntax/ast"

class Crystal::Command
  private def dependencies
    config = create_compiler "tool dependencies", no_codegen: true, dependencies: true

    dependency_printer = DependencyPrinter.new(STDOUT, format: config.dependency_output_format, verbose: config.verbose)

    dependency_printer.includes.concat config.includes.map { |path| ::Path[path].expand.to_s }
    dependency_printer.excludes.concat config.excludes.map { |path| ::Path[path].expand.to_s }
    config.compiler.dependency_printer = dependency_printer

    dependency_printer.start_format
    config.compiler.top_level_semantic config.sources
    dependency_printer.end_format
  end
end

module Crystal
  class DependencyPrinter
    enum Format
      Flat
      Tree
      Dot
      Mermaid
    end

    @depth = 0
    @stack = [] of String
    @filter_depth = Int32::MAX

    @format : Format

    property includes = [] of String
    property excludes = [] of String

    getter default_paths : Array(::Path) = CrystalPath.default_paths.map { |path| ::Path[path].expand }

    def initialize(@io : IO, @format : Format = Format::Tree, @verbose : Bool = false)
    end

    def enter_file(filename : String, unseen : Bool)
      if @depth <= @filter_depth
        filter = filter?(filename)

        if filter
          @filter_depth = @depth
        else
          @filter_depth = Int32::MAX
        end

        if (unseen && !filter) || @verbose
          print_indent if wants_indent?

          print_file(filename, @stack.last?, filter, unseen)
        end
      end

      @stack << filename
      @depth += 1
    end

    def leave_file
      @depth -= 1
      @stack.pop?
    end

    private getter? wants_indent : Bool { @format.tree? }

    def start_format
      case @format
      when .dot?
        @io.puts "digraph G {"
      when .mermaid?
        @io.puts "graph LR"
      end
    end

    def end_format
      case @format
      when .dot?
        @io.puts "}"
      end
    end

    private def print_indent
      @io.print "  " * @depth if @depth > 0
    end

    private def print_file(filename, parent, filter, unseen)
      comment = edge_comment(filter, unseen)
      case @format
      in .dot?
        if parent
          @io.print "  "
          @io.print path(parent)
          @io.print " -> "
          @io.print path(filename)
          @io.print %( [label="#{comment}"]) if comment
          @io.puts
        end
      in .mermaid?
        if parent
          @io.print "  "
          @io.print path(parent)
          @io.print " -->"
          @io.print "|#{comment}|" if comment
          @io.print " "
          @io.print path(filename)
          @io.puts
        end
      in .tree?, .flat?
        @io.print path(filename)
        if comment
          @io.print " "
          @io.print comment
        end
        @io.puts
      end
    end

    private getter? wants_quotes : Bool { @format.dot? }

    private def edge_comment(filter = false, unseen = false)
      if unseen
        "filtered" if filter
      else
        "duplicate skipped"
      end
    end

    private def path(filename)
      relative_path = ::Path[filename].relative_to?(Dir.current) || filename
      wants_quotes? ? relative_path.to_s.inspect : relative_path
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
