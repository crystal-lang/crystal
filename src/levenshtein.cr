require "bit_array"

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
      myers_unicode(string1, string2)
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

  # Myers Algorithm for ASCII and Unicode
  #
  # The algorithm uses uses a dictionary to store string char location as bits
  # ASCII implementation uses StaticArray while for full Unicode a Hash is used
  # The bit width depends on the architecture
  {% begin %}
    {% width = flag?(:bits64) ? 64 : 32 %}
    {% for enc in ["ascii", "unicode"] %}
      private def self.myers_{{ enc.id }}(string1 : String, string2 : String) : Int32
        w = {{ width }}
        one = 1_u{{ width }}
        zero = 0_u{{ width }}
  
        m = string1.size
        n = string2.size
        rmax = (m / w).ceil.to_i
        hna = BitArray.new(n)
        hpa = BitArray.new(n)

        lpos = one << ((m-1) % w)
        score = m

        # Setup char->bit-vector dictionary
        {% if enc == "ascii" %}
          pmr = StaticArray(UInt{{ width }}, 128).new(zero) 
          s1 = string1.to_unsafe
          s2 = string2.to_unsafe
        {% else %}
          pmr = Hash(Int32, UInt{{ width }}).new(w) { zero }
          reader = Char::Reader.new(string1)
          chars = string2.chars
        {% end %}
  
        rmax.times do |r|
          vp = UInt{{ width }}::MAX
          vn = zero

          # populate dictionary
          start = r*w
          count = (r == rmax-1) && ((m % w) != 0) ? (m % w) : w
          count.times do |i|
            {% if enc == "ascii" %}
              pmr[s1[start+i]] |= one << i
            {% else %}
              pmr[reader.current_char.ord] |= one << i
              reader.next_char
            {% end %}
          end

          n.times do |i|
            hn0 = hna[i].to_unsafe
            hp0 = hpa[i].to_unsafe
            # find char in dictionary
            {% if enc == "ascii" %}
              pm = pmr[s2[i]] | hn0
            {% else %}
              pm = pmr[chars[i].ord] | hn0
            {% end %}
            d0 = (((pm & vp) &+ vp) ^ vp) | pm | vn
            hp = vn | ~ (d0 | vp)
            hn = d0 & vp
            if (r == rmax-1) && ((hp & lpos) != 0)
              score += 1
            elsif (r == rmax-1) && ((hn & lpos) != 0)
              score -= 1
            end
            hnx = (hn << 1) | hn0
            hpx = (hp << 1) | hp0
            if (r < rmax-1)
              hna[i] = (hn >> (w-1)) == 1
              hpa[i] = (hp >> (w-1)) == 1
            end
            nc = (r == 0) ? one : zero
            vp = hnx | ~ (d0 | hpx | nc)
            vn = d0 & (hpx | nc)
          end
          # clear dictionary
          {% if enc == "ascii" %}
            pmr.fill(zero)
          {% else %}
            pmr.clear
          {% end %}
        end
        score
      end
    {% end %}
  {% end %}
end
