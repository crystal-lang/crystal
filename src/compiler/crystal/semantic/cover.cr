require "bit_array"

module Crystal
  struct Cover
    getter :arg_types
    getter :matches

    def self.create(arg_types, matches)
      if matches
        matches.empty? ? false : Cover.new(arg_types, matches)
      else
        false
      end
    end

    def initialize(@arg_types, @matches)
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
      cover = BitArray.new(cover_size)
      cover_arg_types = arg_types.map(&.cover)
      matches.each { |match| mark_cover(match, cover, cover_arg_types) }
      {cover, cover_arg_types}
    end

    private def compute_fast_cover
      # Check which arg indices of the matches have types or type restrictions
      args_size = arg_types.size
      indices = BitArray.new(args_size)

      matches.each do |match|
        args_size.times do |i|
          arg = match.def.args[i]
          if arg.type? || arg.restriction
            indices[i] = true
          end
        end
      end

      cover = BitArray.new(cover_size(indices))
      cover_arg_types = arg_types.map_with_index do |arg_type, i|
        indices[i] ? arg_type.cover : nil
      end
      matches.each { |match| mark_cover(match, cover, cover_arg_types, indices) }
      cover
    end

    private def cover_size
      arg_types.reduce(1) do |num, type|
        num * type.cover_size
      end
    end

    private def cover_size(indices)
      i = 0
      arg_types.reduce(1) do |num, type|
        if indices[i]
          val = num * type.cover_size
        else
          val = num
        end
        i += 1
        val
      end
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
      match_arg_type = match.arg_types[index]

      match_arg_type.each do |match_arg_type2|
        match_arg_type2_cover = match_arg_type2.cover
        match_arg_type2_cover = [match_arg_type2_cover] unless match_arg_type2_cover.is_a?(Array)
        match_arg_type2_cover.each do |sub_match_arg_type|
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
end
