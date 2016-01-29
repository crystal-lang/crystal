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

    def move_next
      @iterator.next.tap do |n|
        return false if n.is_a?(Iterator::Stop)
        @values = n.each
        return true
      end
    end

    def read?(t : String.class)
      n = @values.not_nil!.next
      raise "end of row" if n.is_a?(Iterator::Stop)
      return nil if n == "NULL"
      return n as String
    end

    def read?(t : Int32.class)
      read?(String).try &.to_i32
    end

    def read?(t : Int64.class)
      read?(String).try &.to_i64
    end

    def read?(t : Float32.class)
      read?(String).try &.to_f23
    end

    def read?(t : Float64.class)
      read?(String).try &.to_f64
    end
  end
end

DB.register_driver "dummy", DummyDriver

def get_dummy
  DB.open "dummy", {} of String => String
end
