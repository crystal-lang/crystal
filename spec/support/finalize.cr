class State
  @@count = {} of Symbol => Int64

  def self.inc(key)
    @@count[key] = @@count.fetch(key, 0i64) + 1
  end

  def self.count(key)
    @@count.fetch(key, 0i64)
  end

  def self.reset
    @@count.clear
  end
end

def assert_finalizes(key)
  State.reset
  State.count(key).should eq(0)

  10.times do
    obj = yield
    obj.key = key
  end

  GC.collect

  State.count(key).should be > 0
end
