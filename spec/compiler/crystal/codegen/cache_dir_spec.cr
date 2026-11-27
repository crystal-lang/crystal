require "../../../spec_helper"

class Crystal::CacheDir
  class_setter instance

  def initialize(@dir)
    Dir.mkdir_p(dir)
  end
end

private LONG_AGO = Time.utc - 30.days

private def make_entry(name, used_at)
  path = File.join(Crystal::CacheDir.instance.dir, name)
  Dir.mkdir_p(path)
  File.touch(path, used_at)
  path
end

# Leaves no room in the cache for a directory used `LONG_AGO`.
private def make_recent_entries
  (1..10).each { |i| make_entry("recent-#{i}", Time.utc - i.minutes) }
end

# Whether a lock on *dir* would have to wait for another one.
private def locked?(dir, *, shared = false)
  File.open(File.join(dir, Crystal::CacheDir::LOCK_FILE), "a") do |file|
    shared ? file.flock_shared(blocking: false) : file.flock_exclusive(blocking: false)
    false
  rescue IO::Error
    true
  end
end

describe Crystal::CacheDir do
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

  describe "#cleanup" do
    it "removes all but the ten most recently used directories" do
      entries = (1..12).map { |i| make_entry("entry-#{i}", LONG_AGO + i.minutes) }

      CacheDir.instance.cleanup

      entries.first(2).each { |path| Dir.exists?(path).should be_false }
      entries.last(10).each { |path| Dir.exists?(path).should be_true }
    end

    it "keeps a least recently used directory with a shared lock, and removes one without a lock" do
      make_recent_entries
      unlocked = make_entry("unlocked", LONG_AGO)
      locked = make_entry("locked", LONG_AGO)

      File.open(File.join(locked, CacheDir::LOCK_FILE), "a") do |lock|
        lock.flock_shared
        File.touch(locked, LONG_AGO)

        CacheDir.instance.cleanup
      end

      Dir.exists?(locked).should be_true
      Dir.exists?(unlocked).should be_false
    end

    it "keeps files, and doesn't count them among the ten most recently used directories" do
      entries = (1..10).map { |i| make_entry("entry-#{i}", LONG_AGO + i.minutes) }
      removed = make_entry("removed", LONG_AGO)
      file = File.join(CacheDir.instance.dir, "crystal-run-file.tmp")
      File.touch(file)

      CacheDir.instance.cleanup

      File.exists?(file).should be_true
      entries.each { |path| Dir.exists?(path).should be_true }
      Dir.exists?(removed).should be_false
    end
  end

  describe "#lock" do
    it "creates a missing directory and holds an exclusive lock on it" do
      dir = File.join(CacheDir.instance.dir, "build")

      result = CacheDir.instance.lock(dir, :exclusive) do
        locked?(dir, shared: true).should be_true
        :yielded
      end

      result.should eq(:yielded)
      locked?(dir).should be_false
    end

    it "creates a missing directory and holds a shared lock on it" do
      dir = File.join(CacheDir.instance.dir, "macro_run")

      result = CacheDir.instance.lock(dir, :shared) do
        locked?(dir).should be_true
        locked?(dir, shared: true).should be_false
        :yielded
      end

      result.should eq(:yielded)
      locked?(dir).should be_false
    end

    it "keeps an exclusively locked directory from being cleaned up until the lock is released" do
      make_recent_entries
      dir = File.join(CacheDir.instance.dir, "build")

      CacheDir.instance.lock(dir, :exclusive) do
        File.touch(dir, LONG_AGO)
        CacheDir.instance.cleanup
        Dir.exists?(dir).should be_true
      end

      CacheDir.instance.cleanup
      Dir.exists?(dir).should be_false
    end
  end
end
