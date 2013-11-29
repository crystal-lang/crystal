module Crystal
  class Cover
    getter :arg_types
    getter :matches

    def initialize(@arg_types, @matches)
      @arg_types = arg_types
      @matches = matches
    end

    def all?
      if @matches.length == 1
        return @matches[0].arg_types == @arg_types
      end

      compute_fast_cover
      @cover.not_nil!.all?
    end

    def missing
      @cover = nil
      compute_cover

      missing = [] of Array(Type)
      add_missing missing, @cover.not_nil!, @cover_arg_types.not_nil!
      missing
    end

    # private

    def compute_cover
      unless @cover
        cover = @cover = Array(Bool).new(cover_length, false)
        cover_arg_types = @cover_arg_types = @arg_types.map(&.cover)
        @matches.each { |match| mark_cover(match, cover, cover_arg_types) } if @matches
      end
    end

    def compute_fast_cover
      unless @cover
        # Check which arg indices of the matches have types or type restrictions
        indices = @indices = Array(Bool).new(@arg_types.length, false)
        @matches.each do |match|
          match.def.args.each_with_index do |arg, i|
            indices[i] ||= !!(arg.type? || arg.type_restriction)
          end
        end

        cover = @cover = Array(Bool).new(cover_length(indices), false)
        cover_arg_types = @cover_arg_types = @arg_types.map_with_index do |arg_type, i|
          indices[i]? ? arg_type.cover : nil
        end

        @matches.each { |match| mark_cover(match, cover, cover_arg_types, indices) } if @matches
      end
    end

    def cover_length
      @arg_types.inject(1) do |num, type|
        num * type.cover_length
      end
    end

    def cover_length(indices)
      i = 0
      @arg_types.inject(1) do |num, type|
        if indices[i]?
          val = num * type.cover_length
        else
          val = num
        end
        i += 1
        val
      end
    end

    def mark_cover(match, cover, cover_arg_types, indices = nil, index = 0, position = 0, multiplier = 1)
      if index == cover_arg_types.length
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
              new_multiplier = multiplier * arg_type.length
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

    def add_missing(missing, cover, cover_arg_types, types = [] of Type, index = 0, position = 0, multiplier = 1)
      if index == cover_arg_types.length
        unless cover[position]?
          missing.push types.dup
        end
        return
      end

      arg_types = cover_arg_types[index]
      arg_types = [arg_types] unless arg_types.is_a?(Array)
      arg_types.each_with_index do |arg_type, offset|
        types.push arg_type.not_nil!
        new_multiplier = multiplier * arg_types.length
        add_missing missing, cover, cover_arg_types, types, index + 1, position + offset * multiplier, new_multiplier
        types.pop
      end
    end
  end
end
