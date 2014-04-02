require "../types"

module Crystal
  class LLVMId
    def initialize(program)
      @ids = {} of Type => {Int32, Int32}
      @next_id = 0
      assign_id(program.object)
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

    # private

    def assign_id(type : NonGenericClassType)
      assign_id_from_subtypes type, type.subclasses
    end

    def assign_id(type : MetaclassType)
      # Skip for now
      0
    end

    def assign_id(type : GenericClassType)
      assign_id_from_subtypes type, type.generic_types.values
    end

    def assign_id(type : GenericClassInstanceType | PrimitiveType)
      id = next_id
      put_id type, id, id
      id
    end

    def assign_id(type : NilType)
      put_id type, 0, 0
      0
    end

    def assign_id(type)
      raise "Bug: unhandled type in assign id: #{type}"
    end

    def assign_id_from_subtypes(type, subtypes)
      if subtypes.empty?
        id = next_id
        put_id type, id, id
        id
      else
        min_id :: Int32
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

    def put_id(type, min max)
      @ids[type] = {min, max}
    end

    def next_id
      @next_id += 1
    end
  end
end
