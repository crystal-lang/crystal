require "../syntax/ast"
require "../compiler"
require "./typed_def_processor"
require "json"

module Crystal
  class ImplementationResult
    JSON.mapping({
      status:          {type: String},
      message:         {type: String},
      implementations: {type: Array(ImplementationTrace), nilable: true},
    })

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
    JSON.mapping({
      line:     {type: Int32},
      column:   {type: Int32},
      filename: {type: String},
      macro:    {type: String, nilable: true},
      expands:  {type: ImplementationTrace, nilable: true},
    })

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
        raise "not implemented"
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
        return ImplementationResult.new("failed", "no implementations or method call found")
      else
        res = ImplementationResult.new("ok", "#{@locations.size} implementation#{@locations.size > 1 ? "s" : ""} found")
        res.implementations = @locations.map { |loc| ImplementationTrace.build(loc) }
        return res
      end
    end

    def visit(node : Call)
      if node.location
        if @target_location.between?(node.name_location, node.name_end_location)
          if target_defs = node.target_defs
            target_defs.each do |target_def|
              @locations << target_def.location.not_nil!
            end
          end
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
end
