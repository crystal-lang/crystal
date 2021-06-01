require "./grapheme/grapheme"

class String
  # returns an array of all Unicode extended grapheme clusters, specified in the Unicode Standard Annex #29. Grapheme clusters correspond to
  # "user-perceived characters". These characters often consist of multiple code points (e.g. the "woman kissing woman" emoji consists of 8 code points:
  # woman + ZWJ + heavy black heart (2 code points) + ZWJ + kiss mark + ZWJ + woman) and the rules described in Annex #29 must be applied to group those
  # code points into clusters perceived by the user as one character.
  # ```
  # "🧙‍♂️💈".graphemes # => [String::Grapheme::Cluster(@cluster="🧙‍♂️"), String::Grapheme::Cluster(@cluster='💈')]
  # ```
  def graphemes : Array(Grapheme::Cluster)
    graphemes = [] of Grapheme::Cluster
    each_grapheme do |cluster|
      graphemes << cluster
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
  def each_grapheme(& : Grapheme::Cluster -> Nil) : Nil
    grapheme = Grapheme::Graphemes.new(self)
    while cluster = grapheme.next
      yield cluster
    end
  end

  # returns graphemes cluster iterator over Unicode extended grapheme clusters.
  # ```
  # "🔮👍🏼!".each do |cluster|
  #   pp cluster
  # end
  # ```
  def each_grapheme : Iterator(Grapheme::Cluster)
    Grapheme::GraphemeIterator.new(Grapheme::Graphemes.new(self))
  end
end
