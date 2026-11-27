module Crystal
  # Manages cache files in the ".crystal" directory.
  #
  # For each compiled program a directory is created in the cache
  # that stores .bc and .o files that could possibly be reused
  # from a previous compilation.
  #
  # To keep the cache dir small, only the 10 most recently used
  # directories are kept. We use the directory's modification
  # time for this.
  #
  # The cache is shared by every compiler process, so a process locks a
  # directory while it uses it, and a directory that is locked is never
  # removed, whatever its place in the ordering.
  class CacheDir
    # The file in each cache directory that the locks are placed on.
    LOCK_FILE = "compiler.lock"

    def self.instance
      @@instance ||= new
    end

    @dir : String?

    private def initialize
    end

    # Returns the directory where cache files related to the
    # given sources will be stored. The directory will be
    # created if it doesn't exist.
    def directory_for(sources : Array(Compiler::Source))
      directory_for(sources.first.filename)
    end

    # Returns the directory where cache files related to the
    # given filenames will be stored. The directory will be
    # created if it doesn't exist.
    def directory_for(filename : String)
      dir = compute_dir

      filename = ::Path[filename]
      name = String.build do |io|
        filename.each_part do |part|
          if io.empty?
            if part == "#{filename.anchor}"
              part = "#{filename.drive}"[..0]
            end
          else
            io << '-'
          end
          io << part
        end
      end
      output_dir = File.join(dir, name)
      Dir.mkdir_p(output_dir)
      output_dir
    end

    # The lock a process places on a cache directory.
    enum LockType
      # To write to the directory: no other process uses it at the same time.
      Exclusive

      # To read from the directory: other processes may read from it as well.
      Shared

      # Places this lock on *file*, waiting until it is available.
      def place_on(file : File) : Nil
        case self
        in .exclusive? then file.flock_exclusive
        in .shared?    then file.flock_shared
        end
      end
    end

    # Creates the cache directory *dir* if it doesn't exist, and yields while
    # holding a lock of the given *type* on it.
    def lock(dir : String, type : LockType, &)
      loop do
        Dir.mkdir_p(dir)
        file = open_lock_file(dir, type)
        next unless file

        begin
          return yield
        ensure
          file.close
        end
      end
    end

    # Opens the lock file of *dir* and places a lock of the given *type* on it.
    # Returns `nil` if `cleanup` in another process removed the directory.
    private def open_lock_file(dir : String, type : LockType) : File?
      lock_path = File.join(dir, LOCK_FILE)
      file = File.open(lock_path, "a")

      begin
        type.place_on(file)

        # The directory may have been removed before the lock was placed, which
        # leaves the lock on a deleted file.
        locked = File.info?(lock_path).try &.same_file?(file.info)
      ensure
        file.close unless locked
      end

      file if locked
    rescue File::NotFoundError
      nil
    end

    # Keeps the 10 most recently used directories in the cache, and any that
    # is locked, and removes all others.
    def cleanup
      dir = compute_dir
      entries = gather_cache_entries(dir)
      cleanup_dirs(entries)
    end

    # Returns a filename that has prepended the cache directory.
    def join(filename)
      dir = compute_dir
      File.join(dir, filename)
    end

    # Returns the cache directory.
    def dir
      compute_dir
    end

    private def compute_dir
      dir = @dir
      return dir if dir

      # Try to use one of these as a cache directory, in order
      candidates = {% begin %}
        [
          ENV["CRYSTAL_CACHE_DIR"]?,
          {% if flag?(:windows) %}
            ENV["LOCALAPPDATA"]?.try { |dir| "#{dir}/crystal/cache" },
            ENV["USERPROFILE"]?.try { |home| "#{home}/.cache/crystal" },
            ENV["USERPROFILE"]?.try { |home| "#{home}/.crystal" },
          {% else %}
            ENV["XDG_CACHE_HOME"]?.try { |home| "#{home}/crystal" },
            ENV["HOME"]?.try { |home| "#{home}/.cache/crystal" },
            ENV["HOME"]?.try { |home| "#{home}/.crystal" },
          {% end %}
          ".crystal",
        ]
      {% end %}
      candidates = candidates
        .compact
        .map! { |file| File.expand_path(file) }
        .uniq!

      # Return the first one for which we could create a directory
      candidates.each do |candidate|
        Dir.mkdir_p(candidate)
        return @dir = candidate
      rescue File::Error
        # Try next one
      end

      msg = String.build do |io|
        io.puts "Error: can't create cache directory."
        io.puts
        io.puts "Crystal needs a cache directory. These directories were candidates for it:"
        io.puts
        candidates.each do |candidate|
          io << " - " << candidate << '\n'
        end
        io.puts
        io.puts "but none of them are writable."
        io.puts
        io.puts "Please specify a writable cache directory by setting the CRYSTAL_CACHE_DIR environment variable."
      end

      puts msg
      exit 1
    end

    private def cleanup_dirs(entries)
      entries
        .select { |dir| Dir.exists?(dir) }
        .sort_by! { |dir| File.info?(dir).try(&.modification_time) || Time.unix(0) }
        .reverse!
        .skip(10)
        .each { |name| remove_unless_locked(name) }
    end

    # Removes the cache directory *dir*, unless it is locked. The lock is held
    # while removing, so that a process that locks the directory at the same
    # time notices that it is gone.
    private def remove_unless_locked(dir : String) : Nil
      File.open(File.join(dir, LOCK_FILE), "a") do |file|
        file.flock_exclusive(blocking: false)
        FileUtils.rm_rf(dir)
      end
    rescue IO::Error
      # Locked, or already removed
    end

    private def gather_cache_entries(dir)
      Dir.children(dir).map! { |name| File.join(dir, name) }
    end
  end
end
