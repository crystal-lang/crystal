require "../syntax/ast"
require "../compiler"
require "json"

module Crystal
  class Command
    private def macro_code_coverage
      coverage_processor = MacroCoverageProcessor.new

      config = create_compiler "tool macro_code_coverage", path_filter: true, no_codegen: true, allowed_formats: ["codecov"]
      config.compiler.no_codegen = true

      config.compile_configure_program do |program|
        coverage_processor.configure program
      end

      coverage_processor.includes.concat config.includes.map { |path| ::Path[path].expand.to_posix.to_s }

      coverage_processor.excludes.concat CrystalPath.default_paths.map { |path| ::Path[path].expand.to_posix.to_s }
      coverage_processor.excludes.concat config.excludes.map { |path| ::Path[path].expand.to_posix.to_s }

      coverage_processor.process
    end
  end

  class MacroCoverageProcessor
    private CURRENT_DIR = Dir.current

    @hits = Hash(String, Hash(Int32, Int32 | String)).new { |hash, key| hash[key] = Hash(Int32, Int32 | String).new(0) }
    @conditional_hit_cache = Hash(String, Hash(Int32, Set({ASTNode, Bool}))).new { |hash, key| hash[key] = Hash(Int32, Set({ASTNode, Bool})).new { |h, k| h[k] = Set({ASTNode, Bool}).new } }

    @covered_macro_nodes = Array({ASTNode, Location, Bool}).new
    @collected_covered_macro_nodes = Array(Array({ASTNode, Location, Bool})).new
    getter coverage_interrupt_exception : ::Exception? = nil

    # :nodoc:
    def configure(program : Program) : Nil
      program.interpreted_node_hook = ->interpreted_node_hook(ASTNode, Bool, Bool, Location?)
      program.macro_expanded_hook = ->macro_expanded_hook
      program.macro_expansion_error_hook = ->macro_expansion_error_hook(::Exception?)
    end

    protected def interpreted_node_hook(node : ASTNode, missed : Bool = false, use_significant_node : Bool = false, location custom_location : Location? = nil) : Nil
      return unless location = (custom_location || node.location)

      # If desired, try to find a more significant node to use for a more accurate location.
      if use_significant_node
        node = self.find_first_significant_node node
        location = node.try(&.location) || location
      end

      unless location.filename.is_a? String
        return node unless macro_location = location.macro_location

        location = Location.new(
          macro_location.filename,
          location.line_number + macro_location.line_number,
          location.column_number
        )
      end

      @covered_macro_nodes << {node, location, missed}
    end

    protected def macro_expanded_hook : Nil
      @collected_covered_macro_nodes << @covered_macro_nodes.dup
      @covered_macro_nodes.clear
    end

    protected def macro_expansion_error_hook(exception : ::Exception?) : Nil
      @coverage_interrupt_exception = exception unless exception.is_a?(SkipMacroException)
    end

    property includes = [] of String
    property excludes = [] of String

    def process : Nil
      @hits.clear

      self.compute_coverage

      if err = @coverage_interrupt_exception
        puts "Encountered an error while computing coverage report:"
        puts
        err.inspect_with_backtrace STDOUT
        puts
        puts
      end

      self.write_output STDERR

      exit 1 if err
    end

    # See https://docs.codecov.com/docs/codecov-custom-coverage-format
    private def write_output(io : IO) : Nil
      JSON.build io, indent: "  " do |builder|
        builder.object do
          builder.string "coverage"
          builder.object do
            @hits.each do |filename, line_coverage|
              builder.field filename do
                builder.object do
                  line_coverage.to_a.sort_by! { |(line, count)| line }.each do |line, count|
                    builder.field line, count
                  end
                end
              end
            end
          end
        end
      end
    end

    # First filters the nodes to only those with locations we care about.
    # The nodes are then chunked by line number, essentially grouping them.
    # Each group is then processed to determine if that line is a hit or miss, but may also yield more than once, such as to mark an `If` conditional as a hit, but it's `else` block as a miss.
    #
    # The coverage information is stored in a similar way as the resulting output report: https://docs.codecov.com/docs/codecov-custom-coverage-format.
    def compute_coverage
      @collected_covered_macro_nodes
        .select { |nodes| nodes.any? { |(_, location, _)| match_path? location.filename.as(String) } }
        .each do |nodes|
          nodes
            .chunk { |(_, location, _)| location.line_number }
            .each do |(line_number, nodes_by_line)|
              self.process_line(line_number, nodes_by_line) do |(count, location, branches)|
                next unless location.filename.is_a? String

                location = self.normalize_location(location)

                @hits[location.filename][location.line_number] = case existing_hits = @hits[location.filename][location.line_number]?
                                                                 in String
                                                                   hits, _, total = existing_hits.partition '/'

                                                                   "#{(hits.to_i + count).clamp(1, total.to_i)}/#{total}"
                                                                 in Int32 then existing_hits + count
                                                                 in Nil
                                                                   branches && count >= 1 ? "#{count.clamp(1, branches)}/#{branches}" : count
                                                                 end
              end
            end
        end

      @hits
    end

    # These overloads try to find a more significant node to mark as missed.
    # This ensures the missed value in the report maps to an actual node
    # instead of just `{%` in the context of a multi-line `MacroExpression`,
    # or just some whitespace as part of a `MacroLiteral`.

    private def find_first_significant_node(node : MacroExpression) : ASTNode
      self.find_first_significant_node node.exp
    end

    private def find_first_significant_node(node : Expressions) : ASTNode
      if n = node.expressions.reject(MacroLiteral).reject(MultiAssign).first?
        return self.find_first_significant_node n
      end

      node
    end

    private def find_first_significant_node(node : _) : ASTNode
      node
    end

    private alias NodeTuple = {ASTNode, Location, Bool}

    private def process_line(line : Int32, nodes : Array(NodeTuple), & : {Int32, Location, Int32?} ->) : Nil
      # It's safe to use the first location since they were chunked by line.
      _, location, _ = nodes.first

      # Check for conditional hits first so that suffix conditionals are still treated as `1/2`.
      if match = has_conditional_node?(nodes)
        conditional_node, branches = match

        # Keep track of what specific conditional branches were hit and missed as to enure a proper partial count
        # We'll use the last missed node, or the last one if none were missed.
        node, _, missed = nodes.reverse.find(nodes.last) { |_, _, is_missed| !is_missed }
        newly_hit = @conditional_hit_cache[location.filename][location.line_number].add?({node, missed})

        hit_count = if newly_hit
                      if conditional_node.is_a?(If | Unless) && (loc = conditional_node.location) && (end_loc = conditional_node.end_location) && loc.line_number == end_loc.line_number
                        # Special case: Handle suffix `If` and `Unless` given there is no missed node in this context.
                        1
                      elsif nodes.all? { |(_, _, missed)| missed }
                        # If all nodes on this line were missed, it's a miss
                        0
                      else
                        # Otherwise, if no nodes were missed on this line, then all branches of this conditional were hit at once.
                        nodes.none? { |(_, _, missed)| missed } ? branches : 1
                      end
                    else
                      0
                    end

        yield({hit_count, location, branches})
        return
      end

      # If no nodes on this line were missed, we can be assured it was a hit
      if nodes.none? { |(_, _, missed)| missed }
        yield({1, location, nil})
        return
      end

      yield({0, location, nil})
    end

    private def has_conditional_node?(nodes : Array(NodeTuple)) : {ASTNode, Int32}?
      nodes.each do |(node, _, _)|
        if (n = node).is_a?(If | Unless | MacroIf | Or | And) && (branches = self.conditional_statement_branches(n)) > 1
          return node, branches.not_nil!
        end
      end
    end

    # Returns how many unique values a conditional statement could return on a single line.
    private def conditional_statement_branches(node : If | Unless | MacroIf | Or | And) : Int32
      return 1 unless start_location = node.location
      return 1 unless end_location = node.end_location
      return 1 if end_location.line_number > start_location.line_number

      self.count_branches node
    end

    # Workaround for a Crystal 1.0.0 compiler error
    private def conditional_statement_branches(node : ASTNode) : Int32
      1
    end

    private def count_branches(node : Or | And) : Int32
      self.count_branches node.left, node.right
    end

    private def count_branches(node : MacroIf | If | Unless) : Int32
      self.count_branches node.then, node.else
    end

    private def count_branches(left : ASTNode, right : ASTNode) : Int32
      then_depth = case n = left
                   when MacroIf, If, Unless, Or, And then self.count_branches n
                   else
                     1
                   end

      else_depth = case n = right
                   when MacroIf, If, Unless, Or, And then self.count_branches n
                   else
                     1
                   end

      then_depth + else_depth
    end

    private def normalize_location(location : Location) : Location
      Location.new(
        ::Path[location.filename.as(String)].relative_to(CURRENT_DIR).to_s,
        location.line_number,
        location.column_number
      )
    end

    private def match_path?(path)
      paths = ::Path[path].parents << ::Path[path]

      match_any_pattern?(includes, paths) || !match_any_pattern?(excludes, paths)
    end

    private def match_any_pattern?(patterns, paths)
      patterns.any? { |pattern| paths.any? { |path| path == pattern || File.match?(pattern, path.to_posix) } }
    end
  end
end
