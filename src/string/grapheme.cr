require "./grapheme/grapheme"

class String
  # returns an array of all Unicode extended grapheme clusters, specified in the Unicode Standard Annex #29. Grapheme clusters correspond to
  # "user-perceived characters". These characters often consist of multiple code points (e.g. the "woman kissing woman" emoji consists of 8 code points:
  # woman + ZWJ + heavy black heart (2 code points) + ZWJ + kiss mark + ZWJ + woman) and the rules described in Annex #29 must be applied to group those
  # code points into clusters perceived by the user as one character.
  # ```
  # "🧙‍♂️💈".graphemes # => [String::Grapheme::Cluster(@codepoints=[129497, 8205, 9794, 65039], @positions={0, 13}), String::Grapheme::Cluster(@codepoints=[128136], @positions={13, 17})]
  # ```
  def graphemes
    Grapheme::Graphemes.new(self).to_a
  end

  # Yields each Unicode extended grapheme cluster in the string to the block.
  #
  # ```
  # "🧙‍♂️💈".each_grapheme do |cluster|
  #   p! cluster.codepoints
  #   p! cluster.to_s
  # end
  # ```
  def each_grapheme : Nil
    Grapheme::Graphemes.new(self).each do |cluster|
      yield cluster
    end
  end

  # returns graphemes cluster iterator over Unicode extended grapheme clusters.
  # ```
  # "🔮👍🏼!".each do |cluster|
  #   pp cluster.codepoints
  #   pp cluster.positions
  #   pp cluster.str
  #   pp cluster.bytes
  # end
  # ```
  def each_grapheme
    Grapheme::Graphemes.new(self)
  end
end
