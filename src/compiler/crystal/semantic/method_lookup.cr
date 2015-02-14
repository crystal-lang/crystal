require "../types"

module Crystal
  class Type
    def lookup_matches(signature, owner = self, type_lookup = self, matches_array = nil)
      raise "Bug: #{self} doesn't implement lookup_matches"
    end

    def lookup_matches_with_modules(signature, owner = self, type_lookup = self, matches_array = nil)
      raise "Bug: #{self} doesn't implement lookup_matches_with_modules"
    end
  end

  module MatchesLookup
    def lookup_matches_without_parents(signature, owner = self, type_lookup = self, matches_array = nil)
      if defs = self.defs.try &.[signature.name]?
        args_length = signature.arg_types.length
        yields = !!signature.block
        context = MatchContext.new(owner, type_lookup)

        defs.each do |item|
          next if item.def.abstract

          if (item.min_length <= args_length <= item.max_length) && item.yields == yields
            match = MatchesLookup.match_def(signature, item, context)

            if match
              matches_array ||= [] of Match
              matches_array << match

              # If the argument types are compatible with the match's argument types,
              # we are done. We don't just compare types with ==, there is a special case:
              # a function type with return T can be transpass a restriction of a function
              # with with the same arguments but which returns Void.
              if signature.arg_types.equals?(match.arg_types) { |x, y| x.compatible_with?(y) }
                return Matches.new(matches_array, true, owner)
              end
            end
          end
        end
      end

      Matches.new(matches_array, Cover.create(signature.arg_types, matches_array), owner)
    end

    def lookup_matches_with_modules(signature, owner = self, type_lookup = self, matches_array = nil)
      matches = lookup_matches_without_parents(signature, owner, type_lookup, matches_array)
      return matches unless matches.empty?

      if (my_parents = parents) && !(signature.name == "new" && owner.metaclass?)
        my_parents.each do |parent|
          break unless parent.is_a?(IncludedGenericModule) || parent.module?

          matches = parent.lookup_matches_with_modules(signature, owner, parent, matches_array)
          return matches unless matches.empty?
        end
      end

      Matches.new(matches_array, Cover.create(signature.arg_types, matches_array), owner, false)
    end

    def lookup_matches(signature, owner = self, type_lookup = self, matches_array = nil)
      matches = lookup_matches_without_parents(signature, owner, type_lookup, matches_array)
      return matches if matches.cover_all?

      matches_array = matches.matches

      cover = matches.cover

      if (my_parents = parents) && !(signature.name == "new" && owner.metaclass?)
        my_parents.each do |parent|
          matches = parent.lookup_matches(signature, owner, parent, matches_array)
          if matches.cover_all?
            return matches
          else
            matches_array = matches.matches
          end
        end
      end

      Matches.new(matches_array, cover, owner, false)
    end

    def self.match_def(signature, def_metadata, context)
      a_def = def_metadata.def
      arg_types = signature.arg_types
      named_args = signature.named_args
      matched_arg_types = nil

      splat_index = a_def.splat_index || -1

      # Args before the splat argument
      0.upto(splat_index - 1) do |index|
        def_arg = a_def.args[index]
        arg_type = arg_types[index]?

        # Because of default argument
        break unless arg_type

        match_arg_type = match_arg(arg_type, def_arg, context)
        if match_arg_type
          matched_arg_types ||= [] of Type
          matched_arg_types.push match_arg_type
        else
          return nil
        end
      end

      # The splat argument (always matches)
      if splat_index == -1
        splat_length = 0
        offset = 0
      else
        splat_length = arg_types.length - (a_def.args.length - 1)
        offset = splat_index + splat_length

        matched_arg_types ||= [] of Type
        splat_length.times do |i|
          matched_arg_types.push arg_types[splat_index + i]
        end
      end

      # Args after the splat argument
      base = splat_index + 1
      base.upto(a_def.args.length - 1) do |index|
        def_arg = a_def.args[index]
        arg_type = arg_types[offset + index - base]?

        # Because of default argument
        break unless arg_type

        match_arg_type = match_arg(arg_type, def_arg, context)
        if match_arg_type
          matched_arg_types ||= [] of Type
          matched_arg_types.push match_arg_type
        else
          return nil
        end
      end

      # Now check named args
      if named_args
        min_index = signature.arg_types.length
        named_args.each do |named_arg|
          found_index = a_def.args.index { |arg| arg.name == named_arg.name }
          if found_index
            # Check whether the named arg refers to an argument before the first default argument
            if found_index < min_index
              return nil
            end

            unless match_arg(named_arg.value.type, a_def.args[found_index], context)
              return nil
            end
          else
            return nil
          end
        end
      end

      # We reuse a match contextx without free vars, but we create
      # new ones when there are free vars.
      if context.free_vars
        context = context.clone
      end

      Match.new(a_def, (matched_arg_types || arg_types), context)
    end

    def self.match_arg(arg_type, arg : Arg, context : MatchContext)
      restriction = arg.type? || arg.restriction
      match_arg arg_type, restriction, context
    end

    def self.match_arg(arg_type, restriction, context : MatchContext)
      arg_type.not_nil!.restrict restriction, context
    end
  end

  class EmptyType
    def lookup_matches(signature, owner = self, type_lookup = self, matches_array = nil)
      Matches.new(nil, nil, self, false)
    end
  end

  class AliasType
    delegate lookup_matches, aliased_type
  end

  module VirtualTypeLookup
    def lookup_matches(signature, owner = self, type_lookup = self)
      is_new = virtual_metaclass? && signature.name == "new"

      base_type_lookup = virtual_lookup(base_type)
      base_type_matches = base_type_lookup.lookup_matches(signature, self)

      # If there are no subclasses no need to look further
      if leaf?
        return base_type_matches
      end

      base_type_covers_all = base_type_matches.cover_all?

      # If the base type doesn't cover every possible type combination, it's a failure
      if !base_type.abstract && !base_type_covers_all
        return Matches.new(base_type_matches.matches, base_type_matches.cover, base_type_lookup, false)
      end

      type_to_matches = nil
      matches = base_type_matches.matches
      changes = nil

      # Traverse all subtypes
      instance_type.subtypes(base_type).each do |subtype|
        unless subtype.value?
          subtype = subtype as NonGenericOrGenericClassInstanceType

          subtype_lookup = virtual_lookup(subtype)
          subtype_virtual_lookup = virtual_lookup(subtype.virtual_type)

          # Check matches but without parents: only included modules
          subtype_matches = subtype_lookup.lookup_matches_with_modules(signature, subtype_virtual_lookup, subtype_virtual_lookup)

          # For Foo+:Class#new we need to check that this subtype doesn't define
          # an incompatible initialize: if so, we return empty matches, because
          # all subtypes must have an initialize with the same number of arguments.
          if is_new && subtype_matches.empty?
            other_initializers = subtype_lookup.instance_type.lookup_defs_with_modules("initialize")
            unless other_initializers.empty?
              return Matches.new(nil, false)
            end
          end

          # If we didn't find a match in a subclass, and the base type match is a macro
          # def, we need to copy it to the subclass so that @name, @instance_vars and other
          # macro vars resolve correctly.
          if subtype_matches.empty?
            new_subtype_matches = nil

            base_type_matches.each do |base_type_match|
              if base_type_match.def.return_type
                # We need to check if the definition for the method is different than the one in the base type
                full_subtype_matches = subtype_lookup.lookup_matches(signature, subtype_virtual_lookup, subtype_virtual_lookup)
                if full_subtype_matches.any? &.def.same?(base_type_match.def)
                  cloned_def = base_type_match.def.clone
                  cloned_def.macro_owner = base_type_match.def.macro_owner
                  cloned_def.owner = subtype_lookup

                  # We want to add this cloned def at the end, because if we search subtype matches
                  # in the next iteration we will find it, and we don't want that.
                  changes ||= [] of Change
                  changes << Change.new(subtype, cloned_def)

                  new_subtype_matches ||= [] of Match
                  new_subtype_matches.push Match.new(cloned_def, base_type_match.arg_types, MatchContext.new(subtype_lookup, base_type_match.context.type_lookup, base_type_match.context.free_vars))
                end
              end
            end

            if new_subtype_matches
              subtype_matches = Matches.new(new_subtype_matches, Cover.create(signature.arg_types, new_subtype_matches))
            end
          end

          if !subtype.leaf? && subtype_matches.length > 0
            type_to_matches ||= {} of Type => Matches
            type_to_matches[subtype] = subtype_matches
          end

          # If the subtype is non-abstract but doesn't cover all,
          # we need to check if a parent covers it
          if !subtype.abstract && !base_type_covers_all && !subtype_matches.cover_all?
            unless covered_by_superclass?(subtype, type_to_matches)
              return Matches.new(subtype_matches.matches, subtype_matches.cover, subtype_lookup, false)
            end
          end

          if !subtype_matches.empty? && (subtype_matches_matches = subtype_matches.matches)
            if subtype.abstract && subtype.subclasses.empty?
              # No need to add matches if for an abstract class without subclasses
            else
              # We need to insert the matches before the previous ones
              # because subtypes are more specific matches
              if matches
                subtype_matches_matches.concat matches
              end
              matches = subtype_matches_matches
            end
          end
        end
      end

      changes.try &.each do |change|
        change.type.add_def change.def
      end

      Matches.new(matches, (matches && matches.length > 0), self)
    end

    def covered_by_superclass?(subtype, type_to_matches)
      superclass = subtype.superclass
      while superclass && superclass != base_type
        superclass_matches = type_to_matches.try &.[superclass]?
        if superclass_matches && superclass_matches.cover_all?
          return true
        end
        superclass = superclass.superclass
      end
      false
    end
  end
end
