require "../types"

module Crystal
  class Type
    def lookup_similar_type_name(node : Path)
      (node.global ? program : self).lookup_similar_type_name(node.names)
    end

    def lookup_similar_type_name(names : Array, already_looked_up = TypeIdSet.new, lookup_in_container = true)
      nil
    end

    def lookup_similar_def_name(name, args_length, block)
      nil
    end
  end

  module MatchesLookup
    SuggestableName =/\A[a-z_]/

    def lookup_similar_def_name(name, args_length, block)
      return nil unless name =~ SuggestableName

      if (defs = self.defs)
        best_match = SimilarName.find(name) do |similar_name|
          defs.each do |def_name, hash|
            if def_name =~ SuggestableName
              hash.each do |filter, overload|
                if filter.max_length == args_length && filter.yields == !!block
                  similar_name.test(def_name)
                end
              end
            end
          end
        end
        return best_match if best_match
      end

      parents.try &.each do |parent|
        similar_def_name = parent.lookup_similar_def_name(name, args_length, block)
        return similar_def_name if similar_def_name
      end

      nil
    end
  end

  class ModuleType
    def lookup_similar_type_name(names : Array, already_looked_up = TypeIdSet.new, lookup_in_container = true)
      return nil if already_looked_up.includes?(type_id)

      if lookup_in_container
        already_looked_up.add(type_id)
      end

      type = self
      names.each_with_index do |name, idx|
        previous_type = type
        type = previous_type.types[name]?
        unless type
          best_match = SimilarName.find(name.downcase) do |similar_name|
            previous_type.types.each_key do |type_name|
              similar_name.test(type_name.downcase, type_name)
            end
          end

          if best_match
            return (names[0 ... idx] + [best_match]).join "::"
          else
            break
          end
        end
      end

      parents.each do |parent|
        match = parent.lookup_similar_type_name(names, already_looked_up, false)
        return match if match
      end

      lookup_in_container && container ? container.lookup_similar_type_name(names, already_looked_up) : nil
    end
  end

  module InstanceVarContainer
    def lookup_similar_instance_var_name(name)
      SimilarName.find(name, all_instance_vars.keys.select { |key| key != name })
    end
  end

  class IncludedGenericModule
    delegate lookup_similar_def_name, @module
    delegate lookup_similar_type_name, @module
  end

  class InheritedGenericClass
    delegate lookup_similar_def_name, @extended_class
    delegate lookup_similar_type_name, @extended_class
  end

  class AliasType
    delegate lookup_similar_def_name, aliased_type
  end

  class MetaclassType
    delegate lookup_similar_type_name, instance_type
  end

  class GenericClassInstanceMetaclassType
    delegate lookup_similar_type_name, instance_type
  end

  class VirtualType
    delegate lookup_similar_def_name, base_type
    delegate lookup_similar_type_name, base_type
  end

  class VirtualMetaclassType
    delegate lookup_similar_type_name, instance_type
  end
end
