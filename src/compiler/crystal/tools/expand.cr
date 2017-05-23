require "./typed_def_processor"

module Crystal
  struct ExpandResult
    JSON.mapping({
      status:     {type: String},
      message:    {type: String},
      expansions: {type: Array(Expansion), nilable: true},
    })

    def initialize(@status, @message)
    end

    def to_text(io)
      io.puts message
      expansions.try &.each_with_index do |expansion, i|
        io.puts "expansion #{i + 1}:"
        io << "   "
        io.puts expansion.original_source.lines(chomp: false).join "   "
        io.puts
        expansion.expanded_sources.each_with_index do |expanded_source, j|
          io << "~> "
          io.puts expanded_source.lines(chomp: false).join "   "
          io.puts
        end
      end
    end

    struct Expansion
      JSON.mapping({
        original_source:  {type: String},
        expanded_sources: {type: Array(String)},
      })

      def initialize(@original_source, @expanded_sources)
      end

      def self.build(original_node)
        transformer = ExpandTransformer.new
        expanded_node = transformer.transform original_node

        expanded_sources = [] of String

        while transformer.expanded?
          expanded_sources << ast_to_s expanded_node
          transformer.expanded = false
          expanded_node = transformer.transform expanded_node
        end

        Expansion.new ast_to_s(original_node), expanded_sources
      end

      private def self.ast_to_s(node)
        source = String.build { |io| node.to_s(io, emit_doc: true) }

        # Re-indentation is needed for `MacroIf` and `MacroFor`, because they have
        # `MacroBody`, which is sub string of source code, in other words they may
        # contain source code's indent.
        return source unless node.is_a?(MacroIf) || node.is_a?(MacroFor)

        indent = node.location.not_nil!.column_number - 1
        source.lines(chomp: false).map do |line|
          i = 0
          line.each_char do |c|
            break unless c.ascii_whitespace? && i < indent
            i += 1
          end
          line[{i, indent}.min..-1]
        end.join
      end
    end
  end

  class ExpandVisitor < Visitor
    include TypedDefProcessor

    def initialize(@target_location : Location)
      @found_nodes = [] of ASTNode
      @in_defs = false
      @message = "no expansion found"
    end

    def process(result : Compiler::Result)
      @in_defs = true
      process_result result
      @in_defs = false

      result.node.accept(self)

      if @found_nodes.empty?
        return ExpandResult.new("failed", @message)
      else
        res = ExpandResult.new("ok", "#{@found_nodes.size} expansion#{@found_nodes.size > 1 ? "s" : ""} found")
        res.expansions = @found_nodes.map { |node| ExpandResult::Expansion.build(node) }
        return res
      end
    end

    def visit(node : Def | FunDef)
      @in_defs && contains_target(node)
    end

    def visit(node : Call)
      if loc_start = node.location
        # If node.obj (a.k.a. an receiver) is a Path, it may be macro call and node.obj has no expansion surely.
        # Otherwise, we cannot decide node.obj has no expansion.
        loc_start = node.name_location unless node.obj.is_a?(Path)
        loc_end = node.name_end_location
        if @target_location.between?(loc_start, loc_end)
          if node.expanded
            @found_nodes << node
          else
            @message = "no expansion found: #{node} may not be a macro"
          end
          false
        else
          contains_target(node)
        end
      end
    end

    def visit(node : MacroFor | MacroIf | MacroExpression)
      if loc_start = node.location
        loc_end = node.end_location || loc_start
        if @target_location.between?(loc_start, loc_end) && node.expanded
          @found_nodes << node
          false
        else
          contains_target(node)
        end
      end
    end

    def visit(node)
      contains_target(node)
    end

    private def contains_target(node)
      if loc_start = node.location
        loc_end = node.end_location || loc_start
        # if it is not between, it could be the case that node is the top level Expressions
        # in which the (start) location might be in one file and the end location in another.
        @target_location.between?(loc_start, loc_end) || loc_start.filename != loc_end.filename
      else
        # if node has no location, assume they may contain the target.
        # for example with the main expressions ast node this matters
        true
      end
    end
  end

  class ExpandTransformer < Transformer
    property? expanded = false

    def transform(node : Call | MacroFor | MacroIf | MacroExpression)
      if expanded = node.expanded
        self.expanded = true
        expanded
      else
        super
      end
    end
  end
end
