class State
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
        State.inc(key)
      end

      {% if @type.has_method?(:finalize) %}
        previous_def
      {% end %}
    end
  end
end

def assert_finalizes(key : String)
  State.reset
  State.count(key).should eq(0)

  10.times do
    obj = yield
    obj.key = key
  end

  GC.collect

  State.count(key).should be > 0
end
