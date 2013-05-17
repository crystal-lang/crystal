class Cover
  attr_accessor :arg_types
  attr_accessor :matches

  def initialize(arg_types, matches)
    @arg_types = arg_types
    @matches = matches
  end

  def all?
    unless @cover
      @cover = Array.new(@arg_types.inject(1) { |num, type| num * type.cover_length })
      @cover_arg_types = @arg_types.map(&:cover)
      @matches.each { |match| mark_cover(match) }
    end

    @cover.all?
  end

  private

  def mark_cover(match, index = 0, position = 0, multiplier = 1)
    if index == @cover_arg_types.length
      @cover[position] = true
      return
    end

    arg_type = @cover_arg_types[index]
    match_arg_type = match.arg_types[index]

    match_arg_type.each do |match_arg_type2|
      if arg_type.is_a?(Array)
        offset = arg_type.index(match_arg_type2)
        next unless offset
        new_multiplier = multiplier * arg_type.length
      elsif arg_type.equal?(match_arg_type2)
        offset = 0
        new_multiplier = multiplier
      else
        next
      end

      mark_cover match, index + 1, position + offset * multiplier, new_multiplier
    end
  end
end