module DB
  abstract class Statement
    getter driver

    def initialize(@driver)
    end

    abstract def exec(*args) : ResultSet
  end
end
