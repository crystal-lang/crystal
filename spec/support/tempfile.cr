require "file_utils"

{% if flag?(:win32) %}
  SPEC_TEMPFILE_PATH = File.join(Dir.tempdir, "cr-spec-#{Random.new.hex(4)}").gsub("C:\\", '/').gsub('\\', '/')
{% else %}
  SPEC_TEMPFILE_PATH = File.join(Dir.tempdir, "cr-spec-#{Random.new.hex(4)}")
{% end %}

SPEC_TEMPFILE_CLEANUP = ENV["SPEC_TEMPFILE_CLEANUP"]? != "0"

# Expands *paths* in a unique temp folder and yield them to the block.
#
# The *paths* are interpreted relative to a unique folder for every spec run and
# prefixed by the name of the spec file that requests them.
#
# The constructed path is yielded to the block and cleaned up afterwards.
#
# Paths should still be uniquely chosen inside a spec file. This helper
# ensures they're placed in the temporary location (`Dir.tempdir`),
# avoids name clashes between parallel spec runs and cleans up afterwards.
#
# The unique directory for the spec run is removed `at_exit`.
#
# If the environment variable `SPEC_TEMPFILE_CLEANUP` is set to `0`, no paths
# will be cleaned up, enabling easier debugging.
def with_tempfile(*paths, file = __FILE__)
  calling_spec = File.basename(file).rchop("_spec.cr")
  paths = paths.map { |path| File.join(SPEC_TEMPFILE_PATH, calling_spec, path) }
  FileUtils.mkdir_p(File.join(SPEC_TEMPFILE_PATH, calling_spec))

  begin
    yield *paths
  ensure
    if SPEC_TEMPFILE_CLEANUP
      paths.each do |path|
        FileUtils.rm_r(path) if File.exists?(path)
      end
    end
  end
end

if SPEC_TEMPFILE_CLEANUP
  at_exit do
    FileUtils.rm_r(SPEC_TEMPFILE_PATH) if Dir.exists?(SPEC_TEMPFILE_PATH)
  end
end
