require "file_utils"

SPEC_TEMPFILE_PATH    = File.join(Dir.tempdir, "cr-spec-#{Random.new.hex(4)}")
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
        rm_rf(path) if File.exists?(path)
      end
    end
  end
end

def with_temp_executable(name, file = __FILE__)
  {% if flag?(:win32) %}
    name += ".exe"
  {% end %}
  with_tempfile(name, file: file) do |tempname|
    yield tempname
  end
end

def with_temp_c_object_file(c_code, file = __FILE__)
  obj_ext = {{ flag?(:win32) ? ".obj" : ".o" }}
  with_tempfile("temp_c.c", "temp_c#{obj_ext}", file: file) do |c_filename, o_filename|
    File.write(c_filename, c_code)

    {% if flag?(:win32) %}
      `cl.exe /nologo /c #{Process.quote(c_filename)} #{Process.quote("/Fo#{o_filename}")}`.should be_truthy
    {% else %}
      `#{ENV["CC"]? || "cc"} #{Process.quote(c_filename)} -c -o #{Process.quote(o_filename)}`.should be_truthy
    {% end %}

    yield o_filename
  end
end

if SPEC_TEMPFILE_CLEANUP
  at_exit do
    rm_rf(SPEC_TEMPFILE_PATH) if Dir.exists?(SPEC_TEMPFILE_PATH)
  end
end

private def rm_rf(path : String) : Nil
  if Dir.exists?(path) && !File.symlink?(path)
    Dir.each_child(path) do |entry|
      src = File.join(path, entry)
      rm_rf(src)
    end
    Dir.delete(path)
  else
    begin
      File.delete(path)
    rescue File::AccessDeniedError
      # To be able to delete read-only files (e.g. ones under .git/) on Windows.
      File.chmod(path, 0o666)
      File.delete(path)
    end
  end
end
