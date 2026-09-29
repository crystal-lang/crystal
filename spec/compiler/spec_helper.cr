require "../spec_helper"
require "../support/tempfile"

def compiler_datapath(*components)
  File.join("spec", "compiler", "data", *components)
end

class Crystal::CacheDir
  class_setter instance

  def initialize(@dir)
    Dir.mkdir_p(dir)
  end
end

# Runs the block with `CacheDir.instance` pointed at an empty temporary
# directory, so the compiler finds a cold cache, and restores the
# previous instance afterwards.
def with_cold_cache_dir(&)
  old_cache_dir = CacheDir.instance
  temp_dir_name = File.tempname
  begin
    CacheDir.instance = CacheDir.new(temp_dir_name)
    yield
  ensure
    FileUtils.rm_rf(temp_dir_name)
    CacheDir.instance = old_cache_dir
  end
end
