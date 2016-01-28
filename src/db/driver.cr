module DB
  abstract class Driver
    getter options

    def initialize(@options)
    end
  end
end
