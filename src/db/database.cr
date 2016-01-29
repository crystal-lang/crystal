module DB
  # Acts as an entry point for database access.
  # Offers a com
  class Database
    getter driver_class
    getter options

    def initialize(@driver_class, @options)
      @driver = @driver_class.new(@options)
    end

    def prepare(query)
      @driver.prepare(query)
    end

    def exec(query, *args)
      prepare(query).exec(*args)
    end
  end
end
