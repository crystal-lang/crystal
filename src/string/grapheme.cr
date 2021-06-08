require "./grapheme/grapheme"

class String
  # Returns an array of all Unicode extended grapheme clusters, specified in the Unicode Standard Annex #29. Grapheme clusters correspond to
  # "user-perceived characters". These characters often consist of multiple code points (e.g. the "woman kissing woman" emoji consists of 8 code points:
  # woman + ZWJ + heavy black heart (2 code points) + ZWJ + kiss mark + ZWJ + woman) and the rules described in Annex #29 must be applied to group those
  # code points into clusters perceived by the user as one character.
  #
  # ```
  # "🧙‍♂️💈".graphemes # => [String::Grapheme::Cluster(@cluster="🧙‍♂️"), String::Grapheme::Cluster(@cluster='💈')]
  # ```
  def graphemes : Array(Grapheme)
    graphemes = [] of Grapheme
    each_grapheme do |grapheme|
      graphemes << grapheme
    end
    graphemes
  end

  # Yields each Unicode extended grapheme cluster in the string to the block.
  #
  # ```
  # "🧙‍♂️💈".each_grapheme do |cluster|
  #   p! cluster
  # end
  # ```
  def each_grapheme(& : Grapheme -> _) : Nil
    each_grapheme_boundary do |range, last_char|
      yield Grapheme.new(self, range, last_char)
    end
  end

  def grapheme_size : Int32
    size = 0
    each_grapheme_boundary do
      size += 1
    end
    size
  end

  # Returns an iterator of the grapheme clusters in this string.
  #
  # ```
  # "🔮👍🏼!".each_grapheme.to_a # => [String::Grapheme('\u{1f52e}'), String::Grapheme("\u{1F44D}\u{1F3FC}"), String::Grapheme('!')]
  # ```
  def each_grapheme : Iterator(Grapheme)
    GraphemeIterator.new(self)
  end
end
