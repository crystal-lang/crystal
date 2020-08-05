# `TypeDefProcessor` is a mixin to provide a visitor for typed defs
# and some utilities.
#
# It is used for `crystal tool context/expand/implementation`.
module Crystal::TypedDefProcessor
  private def process_typed_def(typed_def : Def)
    typed_def.accept self
  end

  private getter target_location

  private def process_result(result : Compiler::Result)
    process_type result.program
    if file_module = result.program.file_module? target_location.original_filename
      process_type file_module
    end
  end

  private def process_type(type : Type) : Nil
    if type.is_a?(NamedType) || type.is_a?(Program) || type.is_a?(FileModule)
      type.types?.try &.each_value do |inner_type|
        process_type inner_type
      end
    end

    if type.is_a?(GenericType)
      type.generic_types.each_value do |instanced_type|
        process_type instanced_type
      end
    end

    process_type type.metaclass if type.metaclass != type

    if type.is_a?(DefInstanceContainer)
      type.def_instances.each_value do |typed_def|
        process_typed_def typed_def
      end
    end
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
