require "colorize"
require "../syntax/ast"

class Crystal::Command
  private def flags
    OptionParser.parse(@options) do |opts|
      opts.banner = "Usage: crystal tool flags [path...]\n\nOptions:"

      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
      end

      opts.on("--no-color", "Disable colored output") do
        @color = false
      end
    end

    visitor = FlagsVisitor.new
    find_sources(options) do |source|
      Parser.parse(source.code).accept(visitor)
    end
    visitor.flag_names.each do |flag|
      puts flag
    end
  end

  def find_sources(
    paths : Array(String),
    stdin : IO = STDIN,
    & : Compiler::Source ->
  ) : Nil
    stdin_content = nil
    paths.each do |path|
      if path == "-"
        stdin_content ||= stdin.gets_to_end
        yield Compiler::Source.new(path, stdin_content)
      elsif File.file?(path)
        yield Compiler::Source.new(path, File.read(path))
      elsif Dir.exists?(path)
        Dir.glob(::Path[path].to_posix.join("**/*.cr")) do |dir_path|
          if File.file?(dir_path)
            yield Compiler::Source.new(path, File.read(dir_path))
          end
        end
      else
        Crystal.error "file or directory does not exist: #{path}", @color, leading_error: false
      end
    end
  end

  class FlagsVisitor < Visitor
    @in_macro_expression = false

    getter all_flags = [] of ASTNode

    def initialize(@flag_name : String = "flag?")
    end

    def flag_names
      all_flags.map { |flag| string_flag(flag) }.uniq!.sort!
    end

    private def string_flag(node)
      case node
      when StringLiteral, SymbolLiteral
        node.value
      else
        node.to_s
      end
    end

    def visit(node)
      true
    end

    def visit(node : Crystal::MacroExpression | Crystal::MacroIf | Crystal::MacroFor)
      @in_macro_expression = true

      true
    end

    def end_visit(node : Crystal::MacroExpression | Crystal::MacroIf | Crystal::MacroFor)
      @in_macro_expression = false
    end

    def visit(node : Crystal::Call)
      check_call(node)
      true
    end

    private def check_call(node)
      return unless @in_macro_expression
      return unless node.name == @flag_name
      return unless node.obj.nil? && node.block.nil? && node.named_args.nil?

      args = node.args
      return unless args.size == 1
      arg = args[0]

      all_flags << arg
    end
  end
end
