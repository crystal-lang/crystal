# Levensthein distance methods.
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

    s = string1.chars
    t = string2.chars

    s_size = s.size
    t_size = t.size

    return t_size if s_size == 0
    return s_size if t_size == 0

    # This is to allocate less memory
    if t_size > s_size
      t, s = s, t
      t_size, s_size = s_size, t_size
    end

    v = Pointer(Int32).malloc(t_size + 1) { |i| i }

    s_size.times do |i|
      last_cost = i + 1

      t_size.times do |j|
        sub_cost = s[i] == t[j] ? 0 : 1
        cost = Math.min(Math.min(last_cost + 1, v[j + 1] + 1), v[j] + sub_cost)
        v[j] = last_cost
        last_cost = cost
      end
      v[t_size] = last_cost
    end

    v[t_size]
  end

  # Finds the closest string to a given string amongst many strings.
  #
  # ```
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
