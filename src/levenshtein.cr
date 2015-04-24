# Computes the [levenshtein distance](http://en.wikipedia.org/wiki/Levenshtein_distance) of two strings.
#
# ```
# levenshtein("algorithm", "altruistic") #=> 6
# levenshtein("hello", "hallo")          #=> 1
# levenshtein("こんにちは", "こんちは")    #=> 1
# levensthein("hey", "hey")              #=> 0
# ```
def levenshtein(string1 : String, string2 : String)
  return 0 if string1 == string2

  s = string1.chars
  t = string2.chars

  s_len = s.length
  t_len = t.length

  return t_len if s_len == 0
  return s_len if t_len == 0

  # This is to allocate less memory
  if t_len > s_len
    t, s = s, t
    t_len, s_len = s_len, t_len
  end

  v0 = Pointer(Int32).malloc(t_len + 1) { |i| i }
  v1 = Pointer(Int32).malloc(t_len + 1)

  s_len.times do |i|
    v1[0] = i + 1

    0.upto(t_len - 1) do |j|
      cost = s[i] == t[j] ? 0 : 1
      v1[j + 1] = Math.min(Math.min(v1[j] + 1, v0[j + 1] + 1), v0[j] + cost)
    end

    v0.copy_from(v1, t_len + 1)
  end

  v1[t_len]
end

module Levenshtein
  # Finds the closest string to a given string amongst many strings.
  #
  # ```
  # finder = Levenshtein::Finder.new "hallo"
  # finder.test "hay"
  # finder.test "hall"
  # finder.test "hallo world"
  #
  # finder.best_match #=> "hall"
  # ```
  class Finder
    record Entry, value, distance

    def initialize(@target : String, tolerance = nil : Int?)
      @tolerance = tolerance || (target.length / 5.0).ceil.to_i
    end

    def test(name : String, value = name : String)
      distance = levenshtein(@target, name)
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

    def best_match
      @best_entry.try &.value
    end

    def self.find(name, tolerance = nil)
      sn = new name, tolerance
      yield sn
      sn.best_match
    end

    def self.find(name, all_names, tolerance = nil)
      find(name, tolerance) do |similar|
        all_names.each do |a_name|
          similar.test(a_name)
        end
      end
    end
  end

  def self.find(name, tolerance = nil)
    Finder.find(name, tolerance) do |sn|
      yield sn
    end
  end

  def self.find(name, all_names, tolerance = nil)
    Finder.find(name, all_names, tolerance)
  end
end
