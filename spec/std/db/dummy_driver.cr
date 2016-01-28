class DummyDriver < DB::Driver
  def prepare(query)
    DummyStatement.new(self, query.split.map { |r| r.split ',' })
  end

  class DummyStatement < DB::Statement
    def initialize(driver, @items)
      super(driver)
    end

    def exec(*args)
      DummyResultSet.new self, @items.each
    end
  end

  class DummyResultSet < DB::ResultSet
    def initialize(statement, @iterator)
      super(statement)
    end

    def has_next
      @iterator.next.tap do |n|
        return false if n.is_a?(Iterator::Stop)
        @values = n.each
        return true
      end
    end

    def read_string
      @values.not_nil!.next as String
    end

    def read_u_int64
      read_string.to_u64
    end
  end
end

DB.register_driver "dummy", DummyDriver

def get_dummy
  DB.driver "dummy", {} of String => String
end
