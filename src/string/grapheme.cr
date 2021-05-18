require "./grapheme/grapheme"

class String
  # returns graphemes cluster iterator over Unicode extended grapheme clusters, specified in the Unicode Standard Annex #29. Grapheme clusters correspond to
  # "user-perceived characters". These characters often consist of multiple code points (e.g. the "woman kissing woman" emoji consists of 8 code points:
  # woman + ZWJ + heavy black heart (2 code points) + ZWJ + kiss mark + ZWJ + woman) and the rules described in Annex #29 must be applied to group those
  # code points into clusters perceived by the user as one character.
  # ```
  # "🔮👍🏼!".each do |cluster|
  #   pp cluster.codepoints
  #   pp cluster.positions
  #   pp cluster.str
  #   pp cluster.bytes
  # end
  # ```
  def graphemes
    Grapheme::Graphemes.new(self)
  end
end
