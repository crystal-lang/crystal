module DB
  abstract class Driver
    getter options

    def initialize(@options)
    end

    abstract def prepare(query) : Statement
  end
end
