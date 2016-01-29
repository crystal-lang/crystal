class DummyDriver < DB::Driver
  def prepare(query)
    DummyStatement.new(self, query.split.map { |r| r.split ',' })
  end

  class DummyStatement < DB::Statement
    property! params

    def initialize(driver, @items)
      super(driver)
    end

    protected def add_parameter(index : Int32, value)
      params[index] = value
    end

    protected def add_parameter(name : String, value)
      params[":#{name}"] = value
    end

    protected def before_execute
      @params = Hash(Int32 | String, DB::Any).new
    end

    protected def execute
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

    private def read? : DB::Any?
      n = @values.not_nil!.next
      raise "end of row" if n.is_a?(Iterator::Stop)
      return nil if n == "NULL"

      if n == "?"
        return @statement.params[1]
      end

      if n.starts_with?(":")
        return @statement.params[n]
      end

      return n
    end

    def read?(t : String.class)
      read?.try &.to_s
    end

    def read?(t : Int32.class)
      read?(String).try &.to_i32
    end

    def read?(t : Int64.class)
      read?(String).try &.to_i64
    end

    def read?(t : Float32.class)
      read?(String).try &.to_f32
    end

    def read?(t : Float64.class)
      read?(String).try &.to_f64
    end

    def read?(t : Slice(UInt8).class)
      value = read?
      if value.is_a?(Nil)
        value
      elsif value.is_a?(String)
        ary = value.bytes
        Slice.new(ary.to_unsafe, ary.size)
      else
        value as Slice(UInt8)
      end
    end
  end
end

DB.register_driver "dummy", DummyDriver

def get_dummy
  DB.open "dummy", {} of String => String
end
