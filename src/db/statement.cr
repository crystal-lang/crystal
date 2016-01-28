module DB
  abstract class Statement
    def initialize(@driver)
    end

    abstract def exec(*args) : ResultSet
  end
end
