class Cover
  attr_accessor :arg_types
  attr_accessor :matches

  def initialize(arg_types, matches)
    @arg_types = arg_types
    @matches = matches
  end

  def all?
    compute_cover
    @cover.all?
  end

  def missing
    compute_cover

    missing = []
    add_missing missing
    missing
  end

  private

  def compute_cover
    unless @cover
      @cover = Array.new(@arg_types.inject(1) { |num, type| num * type.cover_length })
      @cover_arg_types = @arg_types.map(&:cover)
      @matches.each { |match| mark_cover(match) } if @matches
    end
  end

  def mark_cover(match, index = 0, position = 0, multiplier = 1)
    if index == @cover_arg_types.length
      @cover[position] = true
      return
    end

    arg_type = @cover_arg_types[index]
    match_arg_type = match.arg_types[index]

    match_arg_type.each do |match_arg_type2|
      Array(match_arg_type2.cover).each do |sub_match_arg_type|
        if arg_type.is_a?(Array)
          offset = arg_type.index(sub_match_arg_type)
          next unless offset
          new_multiplier = multiplier * arg_type.length
        elsif arg_type.equal?(sub_match_arg_type)
          offset = 0
          new_multiplier = multiplier
        else
          next
        end

        mark_cover match, index + 1, position + offset * multiplier, new_multiplier
      end
    end
  end

  def add_missing(missing, types = [], index = 0, position = 0, multiplier = 1)
    if index == @cover_arg_types.length
      unless @cover[position]
        missing.push types.clone
      end
      return
    end

    arg_types = Array(@cover_arg_types[index])
    arg_types.each_with_index do |arg_type, offset|
      types.push arg_type
      new_multiplier = multiplier * arg_types.length
      add_missing missing, types, index + 1, position + offset * multiplier, new_multiplier
      types.pop
    end
  end
end
