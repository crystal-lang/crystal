module DB
  # Acts as an entry point for database access.
  # Offers a com
  class Database
    getter driver_class
    getter options

    def initialize(@driver_class, @options)
      @driver = @driver_class.new(@options)
    end

    # :nodoc:
    def prepare(query)
      @driver.prepare(query)
    end

    # :nodoc:
    def exec(query, *args)
      prepare(query).exec(*args)
    end

    def exec_non_query(query, *args)
      exec_query(query) do |result_set|
        result_set.move_next
      end
    end

    # :nodoc:
    def exec_query(query, *args)
      result_set = exec(query, *args)
      yield result_set
      result_set.close
    end

    def exec_query_each(query, *args)
      exec_query(query) do |result_set|
        result_set.each do
          yield result_set
        end
      end
    end
  end
end
