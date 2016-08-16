require "bit_array"
require "../types"

module Crystal
  struct Cover
    getter signature : CallSignature
    getter matches : Array(Match)

    def self.create(signature, matches)
      if matches
        matches.empty? ? false : Cover.new(signature, matches)
      else
        false
      end
    end

    def initialize(@signature, @matches)
    end

    def all?
      compute_fast_cover.all?
    end

    def missing
      cover, cover_arg_types = compute_cover

      missing = [] of Array(Type)
      add_missing missing, cover, cover_arg_types
      missing
    end

    private def compute_cover
      args_size = signature.arg_types.size
      named_args_size = signature.named_args.try(&.size) || 0
      all_args_size = args_size + named_args_size

      cover = BitArray.new(cover_size)
      cover_arg_types = Array(Type | Array(Type) | Nil).new(all_args_size)

      signature.arg_types.each do |arg_type|
        cover_arg_types.push(arg_type.cover)
      end
      signature.named_args.try &.each do |named_arg|
        cover_arg_types.push(named_arg.type.cover)
      end

      matches.each { |match| mark_cover(match, cover, cover_arg_types) }

      {cover, cover_arg_types}
    end

    private def compute_fast_cover
      args_size = signature.arg_types.size
      named_args_size = signature.named_args.try(&.size) || 0
      all_args_size = args_size + named_args_size

      # Check which arg indices of the matches have types or type restrictions
      indices = BitArray.new(all_args_size)

      matches.each do |match|
        match.def.match(signature.arg_types) do |arg, arg_index, arg_type, arg_type_index|
          indices[arg_type_index] = true if arg.type? || arg.restriction
        end

        signature.named_args.try &.each_with_index do |named_arg, i|
          arg = match.def.args.find(&.name.==(named_arg.name))
          if arg && (arg.type? || arg.restriction)
            indices[args_size + i] = true
          end
        end
      end

      cover = BitArray.new(cover_size(indices))
      cover_arg_types = Array(Type | Array(Type) | Nil).new(all_args_size)

      i = 0
      signature.arg_types.each do |arg_type|
        cover_arg_types.push(indices[i] ? arg_type.cover : nil)
        i += 1
      end
      signature.named_args.try &.each do |named_arg|
        cover_arg_types.push(indices[i] ? named_arg.type.cover : nil)
        i += 1
      end

      matches.each { |match| mark_cover(match, cover, cover_arg_types, indices) }

      cover
    end

    private def cover_size
      size = 1
      signature.arg_types.each do |type|
        size *= type.cover_size
      end
      signature.named_args.try &.each do |named_arg|
        size *= named_arg.type.cover_size
      end
      size
    end

    private def cover_size(indices)
      size = 1
      i = 0
      signature.arg_types.each do |type|
        size *= type.cover_size if indices[i]
        i += 1
      end
      signature.named_args.try &.each do |named_arg|
        size *= named_arg.type.cover_size if indices[i]
        i += 1
      end
      size
    end

    private def mark_cover(match, cover, cover_arg_types, indices = nil, index = 0, position = 0, multiplier = 1)
      if index == cover_arg_types.size
        cover[position] = true
        return
      end

      if indices && !indices[index]
        mark_cover match, cover, cover_arg_types, indices, index + 1, position, multiplier
        return
      end

      arg_type = cover_arg_types[index]

      if index < signature.arg_types.size
        match_arg_type = match.arg_types[index]
      else
        match_arg_type = match.named_arg_types.not_nil![index - signature.arg_types.size].type
      end

      match_arg_type.each_cover do |match_arg_type2|
        match_arg_type2_cover = match_arg_type2.cover
        if match_arg_type2_cover.is_a?(Array)
          match_arg_type2_cover.each do |sub_match_arg_type|
            mark_cover_item arg_type, match, cover, cover_arg_types, indices, index, position, multiplier, sub_match_arg_type
          end
        else
          mark_cover_item arg_type, match, cover, cover_arg_types, indices, index, position, multiplier, match_arg_type2_cover
        end
      end
    end

    private def mark_cover_item(arg_type, match, cover, cover_arg_types, indices, index, position, multiplier, sub_match_arg_type)
      if arg_type.is_a?(Array)
        offset = arg_type.index(sub_match_arg_type)
        if offset
          new_multiplier = multiplier * arg_type.size
          mark_cover match, cover, cover_arg_types, indices, index + 1, position + offset * multiplier, new_multiplier
        end
      elsif arg_type == sub_match_arg_type
        offset = 0
        new_multiplier = multiplier
        mark_cover match, cover, cover_arg_types, indices, index + 1, position + offset * multiplier, new_multiplier
      end
    end

    private def add_missing(missing, cover, cover_arg_types, types = [] of Type, index = 0, position = 0, multiplier = 1)
      if index == cover_arg_types.size
        unless cover[position]
          missing.push types.dup
        end
        return
      end

      arg_types = cover_arg_types[index]
      arg_types = [arg_types] unless arg_types.is_a?(Array)
      arg_types.each_with_index do |arg_type, offset|
        types.push arg_type.not_nil!
        new_multiplier = multiplier * arg_types.size
        add_missing missing, cover, cover_arg_types, types, index + 1, position + offset * multiplier, new_multiplier
        types.pop
      end
    end
  end

  class Type
    def each_cover
      yield self
    end

    def cover
      self
    end

    def append_cover(array)
      array << self
    end

    def cover_size
      1
    end
  end

  class NonGenericModuleType
    def cover
      including_types.try(&.cover) || self
    end

    def append_cover(array)
      if including_types = including_types()
        including_types.append_cover(array)
      else
        array << self
      end
    end

    def cover_size
      including_types.try(&.cover_size) || 1
    end
  end

  class UnionType
    def each_cover
      @union_types.each do |union_type|
        yield union_type
      end
    end

    def cover
      cover = [] of Type
      append_cover(cover)
      cover
    end

    def append_cover(array)
      union_types.each &.append_cover(array)
    end

    def cover_size
      union_types.sum &.cover_size
    end
  end

  class VirtualType
    def each_cover
      subtypes.each do |subtype|
        yield subtype
      end
    end

    def cover
      if base_type.abstract?
        cover = [] of Type
        append_cover(cover)
        cover
      else
        base_type
      end
    end

    def append_cover(array)
      if base_type.abstract?
        base_type.subclasses.each &.virtual_type.append_cover(array)
      else
        array << base_type
      end
    end

    def cover_size
      if base_type.abstract?
        base_type.subclasses.sum &.virtual_type.cover_size
      else
        1
      end
    end
  end

  class VirtualMetaclassType
    delegate cover, cover_size, to: instance_type
  end

  class AliasType
    delegate cover, cover_size, to: aliased_type
  end
end
