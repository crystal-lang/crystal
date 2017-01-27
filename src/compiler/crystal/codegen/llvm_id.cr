require "../types"

module Crystal
  # This class assigns a pair of IDs `{min, max}` to every type in the program.
  #
  # For a regular class or struct (not metaclass), this pair
  # of ids is such that `min` is the minimum ID of its subtypes,
  # and `max` is 1 + the maximum ID of its subtypes. In this way
  # we can quickly know if a type implements another type: its ID
  # must be between {min, max} of such type.
  #
  # For example, ids could be assigned like this:
  #
  # - Foo: {1, 8}
  #   - Bar: {1, 2}
  #     - Baz: {1, 1}
  #   - Qux: {3, 3}
  #   - Gen(T): {5, 7}
  #     - Gen(Int32): {4, 4}
  #     - Gen2(T): {5, 6}
  #       - Gen2(Char): {5, 5}
  #
  # Note that generic instances and generic subtypes are considered
  # as subtypes of a generic type.
  #
  # For metaclasses IDs are assigned sequentially as they are needed,
  # because dispatch on metaclasses is less often.
  class LLVMId
    getter id_to_metaclass : Hash(Int32, Int32)

    def initialize(program)
      @ids = {} of Type => {Int32, Int32}
      @id_to_metaclass = {} of Int32 => Int32
      @next_id = 0
      assign_id(program.object)
      assign_id_to_metaclass(program.object)
    end

    def type_id(type : TypeDefType)
      type_id(type.typedef)
    end

    def type_id(type)
      min_max = @ids[type]?
      if min_max
        min_max[1]
      else
        id = next_id
        put_id type, id, id
        id
      end
    end

    def min_max_type_id(type)
      @ids[type]?
    end

    private def assign_id(type)
      min_max_type_id = min_max_type_id(type)
      if min_max_type_id
        min_max_type_id[1]
      else
        assign_id_impl(type)
      end
    end

    private def assign_id_impl(type : NonGenericClassType)
      assign_id_from_subtypes type, subclasses_of(type)
    end

    private def assign_id_impl(type : MetaclassType)
      # Skip for now
      0
    end

    private def assign_id_impl(type : GenericClassType)
      subtypes = type.generic_types.values.reject(&.unbound?)
      subtypes.concat(subclasses_of(type))
      assign_id_from_subtypes type, subtypes
    end

    private def assign_id_impl(type : PrimitiveType)
      id = next_id
      put_id type, id, id
      id
    end

    private def assign_id_impl(type : GenericClassInstanceType)
      assign_id_from_subtypes type, type.subclasses
    end

    private def assign_id_impl(type : NilType)
      put_id type, 0, 0
      0
    end

    private def assign_id_impl(type)
      raise "BUG: unhandled type in assign id: #{type}"
    end

    private def assign_id_from_subtypes(type, subtypes)
      if subtypes.empty?
        id = next_id
        put_id type, id, id
        id
      else
        min_id = uninitialized Int32
        first = true
        subtypes.each do |subtype|
          sub_id = assign_id(subtype)
          if first && sub_id != 0
            min_id = sub_id
            first = false
          end
        end
        id = next_id
        put_id type, min_id, id
        min_id
      end
    end

    private def assign_id_to_metaclass(type : NonGenericClassType)
      assign_id_to_metaclass(type, type.metaclass)
      type.subclasses.each do |subclass|
        assign_id_to_metaclass(subclass)
      end
    end

    private def assign_id_to_metaclass(type : GenericClassInstanceType | PrimitiveType)
      assign_id_to_metaclass(type, type.metaclass)
      type.subclasses.each do |subclass|
        assign_id_to_metaclass(subclass)
      end
    end

    private def assign_id_to_metaclass(type : GenericClassType)
      assign_id_to_metaclass(type, type.metaclass)
      type.generic_types.values.each do |generic_type|
        assign_id_to_metaclass(generic_type)
      end
      type.subclasses.each do |subclass|
        assign_id_to_metaclass(subclass)
      end
    end

    private def assign_id_to_metaclass(type : MetaclassType)
      # Nothing
    end

    private def assign_id_to_metaclass(type)
      raise "BUG: unhandled type in assign id to metaclass: #{type}"
    end

    private def assign_id_to_metaclass(type, metaclass)
      @id_to_metaclass[type_id(type)] = type_id(metaclass)
    end

    private def put_id(type, min, max)
      @ids[type] = {min, max}
    end

    private def next_id
      @next_id += 1
    end

    private def subclasses_of(type)
      type.subclasses.reject(&.is_a?(GenericInstanceType))
    end
  end
end
