require "./grapheme/grapheme"

class String
  # Returns this string split into Unicode extended grapheme clusters.
  #
  # `Grapheme` clusters correspond to "user-perceived characters" and are defined
  # in [Unicode Standard Annex #29](https://unicode.org/reports/tr29/). A cluster
  # can consist of multiple code points which together form a single glyph.
  #
  # ```
  # "a👍🏼à".graphemes # => [String::Grapheme('a'), String::Grapheme("👍🏼"), String::Grapheme("à")]
  # ```
  #
  # * `#each_grapheme` iterates the grapheme clusters without allocating an array
  @[Experimental("The grapheme API is still under development. Join the discussion at [#11610](https://github.com/crystal-lang/crystal/issues/11610).")]
  def graphemes : Array(Grapheme)
    graphemes = [] of Grapheme
    each_grapheme do |grapheme|
      graphemes << grapheme
    end
    graphemes
  end

  # Yields each Unicode extended grapheme cluster in this string.
  #
  # `Grapheme` clusters correspond to "user-perceived characters" and are defined
  # in [Unicode Standard Annex #29](https://unicode.org/reports/tr29/). A cluster
  # can consist of multiple code points which together form a single glyph.
  #
  # ```
  # "a👍🏼à".each_grapheme do |cluster|
  #   p! cluster
  # end
  # ```
  #
  # * `#graphemes` collects all grapheme clusters in an array
  @[Experimental("The grapheme API is still under development. Join the discussion at [#11610](https://github.com/crystal-lang/crystal/issues/11610).")]
  def each_grapheme(& : Grapheme -> _) : Nil
    each_grapheme_boundary do |range, last_char|
      yield Grapheme.new(self, range, last_char)
    end
  end

  # Returns the number of Unicode extended graphemes clusters in this string.
  #
  # * `#each_grapheme` iterates the grapheme clusters.
  @[Experimental("The grapheme API is still under development. Join the discussion at [#11610](https://github.com/crystal-lang/crystal/issues/11610).")]
  def grapheme_size : Int32
    size = 0
    each_grapheme_boundary do
      size += 1
    end
    size
  end

  # Returns an iterator of this string split into Unicode extended grapheme clusters.
  #
  # `Grapheme` clusters correspond to "user-perceived characters" and are defined
  # in [Unicode Standard Annex #29](https://unicode.org/reports/tr29/). A cluster
  # can consist of multiple code points which together form a single glyph.
  #
  # ```
  # "a👍🏼à".each_grapheme.to_a # => [String::Grapheme('a'), String::Grapheme("👍🏼"), String::Grapheme("à")]
  # ```
  #
  # * `#graphemes` collects all grapheme clusters in an array
  @[Experimental("The grapheme API is still under development. Join the discussion at [#11610](https://github.com/crystal-lang/crystal/issues/11610).")]
  def each_grapheme : Iterator(Grapheme)
    GraphemeIterator.new(self)
  end
end
