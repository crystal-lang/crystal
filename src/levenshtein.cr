# Levenshtein distance methods.
module Levenshtein
  # Computes the [levenshtein distance](http://en.wikipedia.org/wiki/Levenshtein_distance) of two strings.
  #
  # ```
  # require "levenshtein"
  #
  # Levenshtein.distance("algorithm", "altruistic") # => 6
  # Levenshtein.distance("hello", "hallo")          # => 1
  # Levenshtein.distance("こんにちは", "こんちは")           # => 1
  # Levenshtein.distance("hey", "hey")              # => 0
  # ```
  def self.distance(string1 : String, string2 : String) : Int32
    return 0 if string1 == string2

    s_size = string1.size
    l_size = string2.size

    if l_size < s_size
      string1, string2 = string2, string1
      l_size, s_size = s_size, l_size
    end

    return l_size if s_size == 0

    if string1.ascii_only? && string2.ascii_only?
      myers_ascii(string1, string2)
    else
      myers(string1, string2)
    end
  end

  # Finds the closest string to a given string amongst many strings.
  #
  # ```
  # require "levenshtein"
  #
  # finder = Levenshtein::Finder.new "hallo"
  # finder.test "hay"
  # finder.test "hall"
  # finder.test "hallo world"
  #
  # finder.best_match # => "hall"
  # ```
  class Finder
    # :nodoc:
    record Entry,
      value : String,
      distance : Int32

    @tolerance : Int32

    def initialize(@target : String, tolerance : Int? = nil)
      @tolerance = tolerance || (target.size / 5.0).ceil.to_i
    end

    def test(name : String, value : String = name)
      distance = Levenshtein.distance(@target, name)
      if distance <= @tolerance
        if best_entry = @best_entry
          if distance < best_entry.distance
            @best_entry = Entry.new(value, distance)
          end
        else
          @best_entry = Entry.new(value, distance)
        end
      end
    end

    def best_match : String?
      @best_entry.try &.value
    end

    def self.find(name, tolerance = nil)
      sn = new name, tolerance
      yield sn
      sn.best_match
    end

    def self.find(name, all_names, tolerance = nil) : String?
      find(name, tolerance) do |similar|
        all_names.each do |a_name|
          similar.test(a_name)
        end
      end
    end
  end

  # Finds the best match for *name* among strings added within the given block.
  # *tolerance* can be used to set maximum Levenshtein distance allowed.
  #
  # ```
  # require "levenshtein"
  #
  # best_match = Levenshtein.find("hello") do |l|
  #   l.test "hulk"
  #   l.test "holk"
  #   l.test "halka"
  #   l.test "ello"
  # end
  # best_match # => "ello"
  # ```
  def self.find(name, tolerance = nil)
    Finder.find(name, tolerance) do |sn|
      yield sn
    end
  end

  # Finds the best match for *name* among strings provided in *all_names*.
  # *tolerance* can be used to set maximum Levenshtein distance allowed.
  #
  # ```
  # require "levenshtein"
  #
  # Levenshtein.find("hello", ["hullo", "hel", "hall", "hell"], 2) # => "hullo"
  # Levenshtein.find("hello", ["hurlo", "hel", "hall"], 1)         # => nil
  # ```
  def self.find(name, all_names, tolerance = nil)
    Finder.find(name, all_names, tolerance)
  end

  # Myers algorithm to solve Levenshtein distance
  private def self.myers(string1 : String, string2 : String) : Int32
    w = 32
    m = string1.size
    n = string2.size
    rmax = (m / w).ceil.to_i
    hna = Array(Int32).new(n, 0)
    hpa = Array(Int32).new(n, 0)

    lpos = 1 << ((m - 1) % w)
    score = m

    pmr = Hash(Int32, UInt32).new(w) { 0.to_u32 }

    rmax.times do |r|
      vp = UInt32::MAX
      vn = 0

      # prepare char bit vector
      s = string1[r*w, w]
      s.each_char_with_index do |c, i|
        pmr[c.ord] |= 1 << i
      end

      string2.each_char_with_index do |c, i|
        hn0 = hna[i]
        hp0 = hpa[i]
        pm = pmr[c.ord] | hn0
        d0 = (((pm & vp) &+ vp) ^ vp) | pm | vn
        hp = vn | ~(d0 | vp)
        hn = d0 & vp
        if (r == rmax - 1) && ((hp & lpos) != 0)
          score += 1
        elsif (r == rmax - 1) && ((hn & lpos) != 0)
          score -= 1
        end
        hnx = (hn << 1) | hn0
        hpx = (hp << 1) | hp0
        hna[i] = (hn >> (w - 1)).to_i32!
        hpa[i] = (hp >> (w - 1)).to_i32!
        nc = (r == 0) ? 1 : 0
        vp = hnx | ~(d0 | hpx | nc)
        vn = d0 & (hpx | nc)
      end

      # Clear char bit vector
      pmr.clear
    end
    score
  end

  # faster ASCII only implementation using StaticArray
  private def self.myers_ascii(string1 : String, string2 : String) : Int32
    w = 32
    m = string1.size
    n = string2.size
    rmax = (m / w).ceil.to_i
    hna = Array(Int32).new(n, 0)
    hpa = Array(Int32).new(n, 0)

    lpos = 1 << ((m - 1) % w)
    score = m
    s1 = string1.to_unsafe
    s2 = string2.to_unsafe

    pmr = StaticArray(UInt32, 128).new(0)

    rmax.times do |r|
      vp = UInt32::MAX
      vn = 0

      # prepare char bit vector
      start = r*w
      count = (r == rmax - 1) && ((m % w) != 0) ? (m % w) : w
      count.times do |i|
        pmr[s1[start + i]] |= 1 << i
      end

      n.times do |i|
        hn0 = hna[i]
        hp0 = hpa[i]
        pm = pmr[s2[i]] | hn0
        d0 = (((pm & vp) &+ vp) ^ vp) | pm | vn
        hp = vn | ~(d0 | vp)
        hn = d0 & vp
        if (r == rmax - 1) && ((hp & lpos) != 0)
          score += 1
        elsif (r == rmax - 1) && ((hn & lpos) != 0)
          score -= 1
        end
        hnx = (hn << 1) | hn0
        hpx = (hp << 1) | hp0
        hna[i] = (hn >> (w - 1)).to_i32!
        hpa[i] = (hp >> (w - 1)).to_i32!
        nc = (r == 0) ? 1 : 0
        vp = hnx | ~(d0 | hpx | nc)
        vn = d0 & (hpx | nc)
      end
      pmr.fill(0)
    end
    score
  end
end
