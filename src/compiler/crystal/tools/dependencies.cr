require "set"
require "colorize"
require "../syntax/ast"

class Crystal::Command
  private def dependencies
    config = create_compiler "tool dependencies", no_codegen: true, dependencies: true

    dependency_printer = DependencyPrinter.create(STDOUT, format: config.dependency_output_format, verbose: config.verbose)

    dependency_printer.includes.concat config.includes.map { |path| ::Path[path].expand.to_s }
    dependency_printer.excludes.concat config.excludes.map { |path| ::Path[path].expand.to_s }
    config.compiler.dependency_printer = dependency_printer

    dependency_printer.start_format
    config.compiler.top_level_semantic config.sources
    dependency_printer.end_format
  end
end

module Crystal
  abstract class DependencyPrinter
    enum Format
      Flat
      Tree
      Dot
      Mermaid
    end

    @stack = [] of String
    @filter_depth = Int32::MAX

    @format : Format

    property includes = [] of String
    property excludes = [] of String

    getter default_paths : Array(::Path) = CrystalPath.default_paths.map { |path| ::Path[path].expand }

    def self.create(io : IO, format : Format = Format::Tree, verbose : Bool = false)
      case format
      in .flat?, .tree?
        List.new(io, format, verbose)
      in .dot?
        Dot.new(io, format, verbose)
      in .mermaid?
        Mermaid.new(io, format, verbose)
      end
    end

    def initialize(@io : IO, @format : Format = Format::Tree, @verbose : Bool = false)
    end

    def enter_file(filename : String, unseen : Bool)
      if @stack.size <= @filter_depth
        filter = filter?(filename)

        if filter
          @filter_depth = @stack.size
        else
          @filter_depth = Int32::MAX
        end

        if (unseen && !filter) || @verbose
          print_indent

          print_file(filename, @stack.last?, filter, unseen)
        end
      end

      @stack << filename
    end

    def leave_file
      @stack.pop
    end

    def start_format
    end

    private def print_indent
    end

    private abstract def print_file(filename, parent, filter, unseen)

    def end_format
    end

    private def edge_comment(filter = false, unseen = false)
      if unseen
        "filtered" if filter
      else
        "duplicate skipped"
      end
    end

    private def path(filename)
      ::Path[filename].relative_to?(Dir.current) || filename
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

    class List < DependencyPrinter
      private def print_file(filename, parent, filter, unseen)
        @io.print path(filename)
        if comment = edge_comment(filter, unseen)
          @io.print " "
          @io.print comment
        end
        @io.puts
      end

      private def print_indent
        @io.print "  " * @stack.size unless @stack.empty?
      end
    end

    class Dot < DependencyPrinter
      def start_format
        @io.puts "digraph G {"
      end

      def end_format
        @io.puts "}"
      end

      private def print_file(filename, parent, filter, unseen)
        return unless parent

        @io.print "  "
        @io.print path(parent)
        @io.print " -> "
        @io.print path(filename)
        if comment = edge_comment(filter, unseen)
          @io.print %( [label="#{comment}"])
        end
        @io.puts
      end

      private def path(filename)
        super.to_s.inspect
      end
    end

    class Mermaid < DependencyPrinter
      def start_format
        @io.puts "graph LR"
      end

      private def print_file(filename, parent, filter, unseen)
        return unless parent

        @io.print "  "
        @io.print path(parent)
        @io.print " -->"
        if comment = edge_comment(filter, unseen)
          @io.print "|#{comment}|"
        end
        @io.print " "
        @io.print path(filename)
        @io.puts
      end
    end
  end
end
