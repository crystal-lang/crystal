require "../syntax/ast"
require "../compiler"

module Crystal
  class Call
    def name_location
      loc = location.not_nil!
      Location.new(loc.line_number, name_column_number, loc.filename)
    end

    def name_end_location
      loc = location.not_nil!
      Location.new(loc.line_number, name_column_number + name_length, loc.filename)
    end
  end

  class Location
    def human_trace
      f = filename
      if f.is_a?(VirtualFile)
        loc = f.expanded_location
        if loc
          loc.human_trace
          puts " ~> #{f} #{f.macro.location}"
        end
      else
        puts self
      end
    end
  end

  class ImplementationsVisitor < Visitor
    getter locations

    def initialize(@target_location)
      @locations = [] of Location
    end

    def process(result : Compiler::Result)
      result.program.def_instances.each_value do |typed_def|
        typed_def.accept(self)
      end

      result.node.accept(self)
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
        loc_end = node.end_location.not_nil!
        @target_location.between?(loc_start, loc_end)
      else
        # if node has no location, assume they may contain the target.
        # for example with the main expressions ast node this matters
        true
      end
    end
  end
end
