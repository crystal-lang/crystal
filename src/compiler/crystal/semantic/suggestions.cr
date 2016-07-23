require "../types"

module Crystal
  class Type
    def lookup_similar_type_name(node : Path)
      (node.global? ? program : self).lookup_similar_type_name(node.names)
    end

    def lookup_similar_type_name(names : Array, already_looked_up = ObjectIdSet.new, lookup_in_container = true)
      nil
    end

    def lookup_similar_def(name, args_size, block)
      nil
    end

    def lookup_similar_def_name(name, args_size, block)
      lookup_similar_def(name, args_size, block).try &.name
    end
  end

  module MatchesLookup
    SuggestableName = /\A[a-z_]/

    def lookup_similar_def(name, args_size, block)
      return nil unless name =~ SuggestableName

      if (defs = self.defs)
        best_def = nil
        best_match = nil
        Levenshtein.find(name) do |finder|
          defs.each do |def_name, hash|
            if def_name =~ SuggestableName
              hash.each do |def_with_metadata|
                if def_with_metadata.max_size == args_size && def_with_metadata.yields == !!block && def_with_metadata.def.name != name
                  finder.test(def_name)
                  if finder.best_match != best_match
                    best_match = finder.best_match
                    best_def = def_with_metadata.def
                  end
                end
              end
            end
          end
        end
        return best_def if best_def
      end

      parents.try &.each do |parent|
        similar_def = parent.lookup_similar_def(name, args_size, block)
        return similar_def if similar_def
      end

      nil
    end
  end

  class ModuleType
    def lookup_similar_type_name(names : Array, already_looked_up = ObjectIdSet.new, lookup_in_container = true)
      return nil if already_looked_up.includes?(object_id)

      if lookup_in_container
        already_looked_up.add(object_id)
      end

      type = self
      names.each_with_index do |name, idx|
        previous_type = type
        type = previous_type.types?.try &.[name]?
        unless type
          best_match = Levenshtein.find(name.downcase) do |finder|
            previous_type.types?.try &.each_key do |type_name|
              finder.test(type_name.downcase, type_name)
            end
          end

          if best_match
            return (names[0...idx] + [best_match]).join "::"
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
      Levenshtein.find(name, all_instance_vars.keys.select { |key| key != name })
    end
  end

  class IncludedGenericModule
    delegate lookup_similar_def, lookup_similar_type_name, to: @module
  end

  class InheritedGenericClass
    delegate lookup_similar_def, lookup_similar_type_name, to: @extended_class
  end

  class AliasType
    delegate lookup_similar_def, to: aliased_type
  end

  class MetaclassType
    delegate lookup_similar_type_name, to: instance_type
  end

  class GenericClassInstanceMetaclassType
    delegate lookup_similar_type_name, to: instance_type
  end

  class VirtualType
    delegate lookup_similar_def, lookup_similar_type_name, to: base_type
  end

  class VirtualMetaclassType
    delegate lookup_similar_type_name, to: instance_type
  end
end
