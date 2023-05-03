module FinalizeState
  @@count = {} of String => Int64

  def self.inc(key : String)
    @@count[key] = @@count.fetch(key, 0i64) + 1
  end

  def self.count(key : String)
    @@count.fetch(key, 0i64)
  end

  def self.reset
    @@count.clear
  end
end

module FinalizeCounter
  macro included
    property key : String?

    def finalize
      if key = @key
        FinalizeState.inc(key)
      end

      {% if @type.has_method?(:finalize) %}
        previous_def
      {% end %}
    end
  end
end

def assert_finalizes(key : String, *, file = __FILE__, line = __LINE__, &)
  FinalizeState.reset
  FinalizeState.count(key).should eq(0_i64), file: file, line: line

  10.times do
    obj = yield
    obj.key = key
  end

  GC.collect

  FinalizeState.count(key).should be > 0, file: file, line: line
end
