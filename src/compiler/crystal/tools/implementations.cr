require "../syntax/ast"
require "../compiler"
require "./typed_def_processor"
require "json"

module Crystal
  class ImplementationResult
    include JSON::Serializable
    property status : String
    property message : String
    property implementations : Array(ImplementationTrace)?

    def initialize(@status, @message)
    end

    def to_text(io)
      io.puts message
      implementations.try do |arr|
        arr.each do |impl|
          io.puts "#{impl.filename}:#{impl.line}:#{impl.column}"
          expanded = impl.expands
          while expanded
            io.puts " ~> macro #{expanded.macro}: #{expanded.filename}:#{expanded.line}:#{expanded.column}"
            expanded = expanded.expands
          end
        end
      end
    end
  end

  # Contains information regarding where an implementation is defined.
  # It keeps track of macro expansion in a human friendly way and
  # pointing to the exact line an expansion and method definition occurs.
  class ImplementationTrace
    include JSON::Serializable

    property line : Int32
    property column : Int32
    property filename : String
    property macro : String?
    property expands : ImplementationTrace?

    def initialize(loc : Location)
      f = loc.filename
      if f.is_a?(String)
        @line = loc.line_number
        @column = loc.column_number
        @filename = f
      elsif f.is_a?(VirtualFile)
        macro_location = f.macro.location.not_nil!
        @macro = f.macro.name
        @filename = macro_location.filename.to_s
        @line = macro_location.line_number + loc.line_number
        @column = loc.column_number
      else
        @line = loc.line_number
        @column = loc.column_number
        @filename = "<unknown>"
      end
    end

    def self.parent(loc : Location)
      f = loc.filename

      if f.is_a?(VirtualFile)
        f.expanded_location
      else
        nil
      end
    end

    def self.build(loc : Location)
      res = self.new(loc)
      parent = self.parent(loc)

      while parent
        outer = self.new(parent)
        parent = self.parent(parent)

        outer.expands = res
        res = outer
      end

      res
    end
  end

  class ImplementationsVisitor < Visitor
    include TypedDefProcessor

    getter locations : Array(Location)

    def initialize(@target_location : Location)
      @locations = [] of Location
    end

    def process(result : Compiler::Result)
      process_result result

      result.node.accept(self)

      if @locations.empty?
        ImplementationResult.new("failed", "no implementations or method call found")
      else
        res = ImplementationResult.new("ok", "#{@locations.size} implementation#{@locations.size > 1 ? "s" : ""} found")
        res.implementations = @locations.map { |loc| ImplementationTrace.build(loc) }
        res
      end
    end

    def visit(node : Call)
      return contains_target(node) unless node.location && @target_location.between?(node.name_location, node.name_end_location)

      if target_defs = node.target_defs
        target_defs.each do |target_def|
          @locations << (target_def.location || Location.new(nil, 0, 0))
        end
      end
      false
    end

    def visit(node : Path)
      return contains_target(node) unless (loc = node.location) && (end_loc = node.end_location) && @target_location.between?(loc, end_loc)

      target = node.target_const || node.target_type
      target.try &.locations.try &.each do |loc|
        @locations << loc
      end
      false
    end

    def visit(node)
      contains_target(node)
    end
  end
end
