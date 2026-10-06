require "spec"
require "crystal/lru_cache"

# LRUCache generic over K, V
describe Crystal::LRUCache do
  describe "#fetch" do
    it "returns value for existing key and moves it to head" do
      cache = Crystal::LRUCache(Int32, String).new(3)
      cache.put(1, "a")
      cache.put(2, "b")
      cache.put(3, "c")
      cache.fetch(2) { nil }.should eq("b") # key 2 should be most recently used
      cache.put(4, "d")                     # should evict key 1
      cache.fetch(1) { nil }.should be_nil, "Expected key 1 to have been evicted."
      cache.fetch(2) { nil }.should eq("b")
      cache.fetch(3) { nil }.should eq("c")
      cache.fetch(4) { nil }.should eq("d")
    end

    it "yields and returns yielded value when key is missing" do
      cache = Crystal::LRUCache(Int32, String).new(5)
      cache.put(1, "one")
      cache.fetch(2) { "default" }.should eq("default")
      cache.fetch(2) { nil }.should be_nil
    end
  end

  describe "#put" do
    it "updates existing key and moves it to head" do
      cache = Crystal::LRUCache(Int32, String).new(2)
      cache.put(1, "first")
      cache.put(2, "second")
      cache.put(1, "updated") # key 1 should be most recently used
      cache.put(3, "third")   # should evict key 2
      cache.fetch(2) { nil }.should be_nil, "Expected key 2 to have been evicted"
      cache.fetch(1) { nil }.should eq("updated")
      cache.fetch(3) { nil }.should eq("third")
    end
  end

  it "works correctly with capacity 1" do
    cache = Crystal::LRUCache(Int32, String).new(1)
    cache.put(1, "a")
    cache.put(2, "b") # should evict 1
    cache.fetch(1) { "not found" }.should eq("not found")
    cache.fetch(2) { "not found" }.should eq("b")
  end
end
