require "levenshtein"

module Crystal
  class SimilarName
    record Entry, value, distance

    def initialize(@name)
      @tolerance = (name.length / 5.0).ceil.to_i
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

    def self.find(name)
      sn = new name
      yield sn
      sn.best_match
    end

    def self.find(name, all_names)
      SimilarName.find(name) do |similar|
        all_names.each do |a_name|
          similar.test(a_name)
        end
      end
    end
  end
end
