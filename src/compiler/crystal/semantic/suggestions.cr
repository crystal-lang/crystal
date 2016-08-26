require "levenshtein"
require "../types"

module Crystal
  class Type
    SuggestableDefName = /\A[a-z_]/

    def lookup_similar_path(node : Path)
      (node.global? ? program : self).lookup_similar_path(node.names)
    end

    def lookup_similar_path(names : Array(String), lookup_in_namespace = true)
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

      parents.try &.each do |parent|
        match = parent.lookup_similar_path(names, false)
        return match if match
      end

      lookup_in_namespace && self != program ? namespace.lookup_similar_path(names) : nil
    end

    def lookup_similar_def(name, args_size, block)
      return nil unless name =~ SuggestableDefName

      if (defs = self.defs)
        best_def = nil
        best_match = nil
        Levenshtein.find(name) do |finder|
          defs.each do |def_name, hash|
            if def_name =~ SuggestableDefName
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

    def lookup_similar_def_name(name, args_size, block)
      lookup_similar_def(name, args_size, block).try &.name
    end

    def lookup_similar_instance_var_name(name)
      Levenshtein.find(name, all_instance_vars.keys.select { |key| key != name })
    end
  end

  class AliasType
    delegate lookup_similar_def, to: aliased_type
  end

  class MetaclassType
    delegate lookup_similar_path, to: instance_type
  end

  class GenericClassInstanceMetaclassType
    delegate lookup_similar_path, to: instance_type
  end

  class GenericModuleInstanceMetaclassType
    delegate lookup_similar_path, to: instance_type
  end

  class VirtualType
    delegate lookup_similar_def, lookup_similar_path, to: base_type
  end

  class VirtualMetaclassType
    delegate lookup_similar_path, to: instance_type
  end
end
