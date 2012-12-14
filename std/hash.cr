class Hash
  def initialize
    @buckets = []
    17.times { @buckets.push [] }
  end

  def []=(key, value)
    index = bucket_index key
    unless bucket = @buckets[index]
      @buckets[index] = bucket = []
    end
    bucket.each do |entry|
      if key == entry.key
        return entry.value
      end
    end
    entry = Entry.new(key, value)
    bucket.push entry
    value
  end

  def [](key)
    index = bucket_index key
    bucket = @buckets[index]
    return nil unless bucket

    bucket.each do |entry|
      if entry.key == key
        return entry.value
      end
    end

    nil
  end

  def to_s
    str = "{"
    found_one = false
    @buckets.each do |bucket|
      bucket.each do |entry|
        str += ", " if found_one
        str += entry.key.inspect
        str += "=>"
        str += entry.value.inspect
        found_one = true
      end
    end
    str += "}"
  end

  # private

  def bucket_index(key)
    key.hash % @buckets.length
  end

  class Entry
    def initialize(key, value)
      @key = key
      @value = value
    end

    def key
      @key
    end

    def value
      @value
    end

    def to_s
      "Entry[#{@key}, #{@value}]"
    end
  end
end