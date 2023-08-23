require "../syntax/ast"
require "../compiler"
require "json"

module Crystal
  record UnreachableResult, defs : Array(Def) do
    include JSON::Serializable

    def to_text(io)
      defs.each do |a_def|
        io << a_def.short_reference << "\t" << a_def.location
        io.puts
      end
    end

    def to_json(builder : JSON::Builder)
      builder.array do
        defs.each do |a_def|
          builder.object do
            builder.field "name", a_def.short_reference
            builder.field "location", a_def.location
          end
        end
      end
    end
  end

  class UnreachableVisitor < Visitor
    # object_id of used defs, extracted from DefInstanceKey of typed_defs
    @def_object_ids = Set(UInt64).new
    @used_def_locations = Set(Location).new
    @defs = [] of Def

    def initialize(@filename : String)
    end

    def process_type(type)
      if type.is_a?(NamedType)
        type.types?.try &.values.each do |inner_type|
          process_type(inner_type)
        end
      end

      return unless type.is_a?(DefInstanceContainer)
      return unless type.is_a?(ModuleType)
      track_used_defs type
      track_unused_defs type
    end

    def process(result : Compiler::Result)
      @def_object_ids.clear
      @defs.clear

      result.node.accept(self)

      track_used_defs result.program
      track_unused_defs result.program

      result.program.types?.try &.values.each do |type|
        process_type type
        if metaclass = type.metaclass
          process_type metaclass
        end
      end

      UnreachableResult.new @defs
    end

    def visit(node)
      true
    end

    def visit(node : Call)
      # Some defs (yielding, generic or virtual owner) are separate
      # instantiations and thus cannot be identified by a unique object_id. Thus
      # we're looking for location to identify the base def.
      node.target_defs.try &.each do |a_def|
        if location = a_def.location
          @used_def_locations << location
        end
      end

      true
    end

    private def track_used_defs(container : DefInstanceContainer)
      container.def_instances.each_key do |def_instance_key|
        @def_object_ids << def_instance_key.def_object_id
      end
    end

    private def track_unused_defs(module_type : ModuleType)
      module_type.defs.try &.each_value.each do |defs_with_meta|
        defs_with_meta.each do |def_with_meta|
          check_def(def_with_meta.def)
        end
      end
    end

    private def check_def(a_def : Def)
      return unless interested_in(a_def.location)

      previous = a_def.previous.try(&.def)

      check_def(previous) if previous && !a_def.calls_previous_def?

      return if @def_object_ids.includes?(a_def.object_id)
      return if @used_def_locations.includes?(a_def.location)

      check_def(previous) if previous && a_def.calls_previous_def?

      @defs << a_def
    end

    private def interested_in(location)
      (loc_filename = location.try &.filename) && loc_filename.is_a?(String) && loc_filename.starts_with?(@filename)
    end
  end
end
