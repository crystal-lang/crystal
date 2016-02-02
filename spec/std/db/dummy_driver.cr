require "spec"

class DummyDriver < DB::Driver
  def build_connection
    DummyConnection.new(connection_string)
  end

  class DummyConnection < DB::Connection
    def prepare(query)
      DummyStatement.new(self, query)
    end

    def last_insert_id : Int64
      0
    end

    def perform_close
    end
  end

  class DummyStatement < DB::Statement
    property params

    def initialize(driver, @query)
      @params = Hash(Int32 | String, DB::Any).new
      super(driver)
    end

    protected def perform(args : Slice(DB::Any))
      @params.clear
      args.each_with_index do |arg, index|
        @params[index] = arg
      end
      DummyResultSet.new self, @query
    end
  end

  class DummyResultSet < DB::ResultSet
    @@next_column_type = String

    def initialize(statement, query)
      super(statement)
      @iterator = query.split.map { |r| r.split(',') }.to_a.each

      @executed = false
      @@last_result_set = self
    end

    def self.last_result_set
      @@last_result_set.not_nil!
    end

    def executed?
      @executed
    end

    def move_next
      @executed = true
      @iterator.next.tap do |n|
        return false if n.is_a?(Iterator::Stop)
        @values = n.each
        return true
      end
    end

    def column_count
      2
    end

    def column_name(index)
      "c#{index}"
    end

    def column_type(index : Int32)
      @@next_column_type
    end

    def self.next_column_type=(value)
      @@next_column_type = value
    end

    private def read? : DB::Any?
      n = @values.not_nil!.next
      raise "end of row" if n.is_a?(Iterator::Stop)
      return nil if n == "NULL"

      if n == "?"
        return @statement.params[0]
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
      elsif value.is_a?(Slice(UInt8))
        value
      else
        raise "#{value} is not convertible to Slice(UInt8)"
      end
    end
  end
end

DB.register_driver "dummy", DummyDriver

class Witness
  getter count

  def initialize(@count)
  end

  def check
    @count -= 1
  end
end

def with_witness(count = 1)
  w = Witness.new(count)
  yield w
  w.count.should eq(0), "The expected coverage was unmet"
end

def with_dummy
  DB.open "dummy", "" do |db|
    yield db
  end
end
