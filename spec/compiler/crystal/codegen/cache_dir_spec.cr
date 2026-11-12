require "../../../spec_helper"

class Crystal::CacheDir
  class_setter instance

  def initialize(@dir)
    Dir.mkdir_p(dir)
  end
end

private def make_entry(name, used_at)
  path = File.join(Crystal::CacheDir.instance.dir, name)
  Dir.mkdir_p(path)
  File.touch(path, used_at)
  path
end

describe Crystal::CacheDir do
  describe "#cleanup" do
    around_each do |example|
      old_cache_dir = CacheDir.instance
      temp_dir_name = File.tempname
      begin
        CacheDir.instance = CacheDir.new(temp_dir_name)
        example.run
      ensure
        FileUtils.rm_rf(temp_dir_name)
        CacheDir.instance = old_cache_dir
      end
    end

    it "keeps the ten most recently used directories" do
      long_ago = Time.utc - 30.days
      entries = (1..12).map { |i| make_entry("entry-#{i}", long_ago + i.minutes) }

      CacheDir.instance.cleanup

      entries.first(2).each { |path| Dir.exists?(path).should be_false }
      entries.last(10).each { |path| Dir.exists?(path).should be_true }
    end

    it "keeps a directory another process holds a lock in" do
      long_ago = Time.utc - 30.days
      (1..10).each { |i| make_entry("newer-#{i}", Time.utc - i.minutes) }
      unlocked = make_entry("unlocked", long_ago)

      locked = File.join(CacheDir.instance.dir, "locked")
      Dir.mkdir_p(locked)
      File.open(File.join(locked, CacheDir::LOCK_FILE), "a") do |lock|
        lock.flock_shared
        File.touch(locked, long_ago)

        CacheDir.instance.cleanup
      end

      Dir.exists?(locked).should be_true
      Dir.exists?(unlocked).should be_false
    end

    it "keeps a directory this process uses" do
      in_use = CacheDir.instance.directory_for("in_use.cr")
      File.touch(in_use, Time.utc - 30.days)
      (1..10).each { |i| make_entry("newer-#{i}", Time.utc - i.minutes) }

      CacheDir.instance.cleanup

      Dir.exists?(in_use).should be_true
    end
  end
end
