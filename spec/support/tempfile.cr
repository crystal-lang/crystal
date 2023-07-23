require "file_utils"
{% if flag?(:msvc) %}
  require "crystal/system/win32/visual_studio"
{% end %}

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
def with_tempfile(*paths, file = __FILE__, &)
  calling_spec = File.basename(file).rchop("_spec.cr")
  paths = paths.map { |path| File.join(SPEC_TEMPFILE_PATH, calling_spec, path) }
  FileUtils.mkdir_p(File.join(SPEC_TEMPFILE_PATH, calling_spec))

  begin
    yield *paths
  ensure
    if SPEC_TEMPFILE_CLEANUP
      paths.each do |path|
        FileUtils.rm_rf(path) if File.exists?(path)
      end
    end
  end
end

def with_temp_executable(name, file = __FILE__, &)
  {% if flag?(:win32) %}
    name += ".exe"
  {% end %}
  with_tempfile(name, file: file) do |tempname|
    yield tempname
  end
end

def with_temp_c_object_file(c_code, *, filename = "temp_c", file = __FILE__, &)
  obj_ext = {{ flag?(:msvc) ? ".obj" : ".o" }}
  with_tempfile("#{filename}.c", "#{filename}#{obj_ext}", file: file) do |c_filename, o_filename|
    File.write(c_filename, c_code)

    {% if flag?(:msvc) %}
      # following is based on `Crystal::Compiler#linker_command`
      unless cl = ENV["CC"]?
        cl = "cl.exe"
        if msvc_path = Crystal::System::VisualStudio.find_latest_msvc_path
          # we won't be cross-compiling the specs binaries, so host and target
          # bits are identical
          bits = {{ flag?(:bits64) ? "x64" : "x86" }}
          cl = Process.quote(msvc_path.join("bin", "Host#{bits}", bits, cl).to_s)
        end
      end

      `#{cl} /nologo /c #{Process.quote(c_filename)} #{Process.quote("/Fo#{o_filename}")}`.should be_truthy
    {% else %}
      `#{ENV["CC"]? || "cc"} #{Process.quote(c_filename)} -c -o #{Process.quote(o_filename)}`.should be_truthy
    {% end %}

    yield o_filename
  end
end

if SPEC_TEMPFILE_CLEANUP
  at_exit do
    FileUtils.rm_rf(SPEC_TEMPFILE_PATH) if Dir.exists?(SPEC_TEMPFILE_PATH)
  end
end
