require "levenshtein"

module Crystal
  class SimilarName
    record Entry, value, distance

    def initialize(@name)
      @tolerance = (name.length / 5.0).ceil
    end

    def test(name, value = name)
      distance = levenshtein(@name, name)
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

    def self.find(name, all_names)
      similar = SimilarName.new(name)
      all_names.each do |a_name|
        similar.test(a_name)
      end
      similar.best_match
    end
  end
end
