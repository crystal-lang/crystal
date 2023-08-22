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

    private def track_used_defs(container : DefInstanceContainer)
      container.def_instances.each_key do |def_instance_key|
        @def_object_ids << def_instance_key.def_object_id
      end
    end

    private def track_unused_defs(module_type : ModuleType)
      return if module_type.is_a?(GenericType) # TODO: This avoids false positives
      module_type.defs.try &.each_value.each do |defs_with_meta|
        defs_with_meta.each do |def_with_meta|
          next if def_with_meta.yields # TODO: This avoids false positives
          next unless interested_in(def_with_meta.def.location)
          next if @def_object_ids.includes?(def_with_meta.def.object_id)

          @defs << def_with_meta.def
        end
      end
    end

    private def interested_in(location)
      (loc_filename = location.try &.filename) && loc_filename.is_a?(String) && loc_filename.starts_with?(@filename)
    end
  end
end
