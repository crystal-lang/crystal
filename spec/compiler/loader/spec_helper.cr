require "spec"

SPEC_CRYSTAL_LOADER_LIB_PATH = File.join(SPEC_TEMPFILE_PATH, "loader")

def build_c_dynlib(c_filename, *, lib_name = nil, target_dir = SPEC_CRYSTAL_LOADER_LIB_PATH)
  o_filename = File.join(target_dir, Crystal::Loader.library_filename(lib_name || File.basename(c_filename, ".c")))

  {% if flag?(:msvc) %}
    o_basename = o_filename.rchop(".lib")
    Process.run(ENV.fetch("CC", "cl.exe"), {"/nologo", "/LD", c_filename, "/Fo#{o_basename}", "/Fe#{o_basename}"})
  {% elsif flag?(:win32) && flag?(:gnu) %}
    o_basename = o_filename.rchop(".a")
    Process.run(ENV.fetch("CC", "cc"), {"-shared", "-fvisibility=hidden", c_filename, "-o", "#{o_basename}.dll", "-Wl,--out-implib,#{o_basename}.a"})
  {% else %}
    Process.run(ENV.fetch("CC", "cc"), {"-shared", "-fvisibility=hidden", c_filename, "-o", o_filename})
  {% end %}

  raise "BUG: failed to compile dynamic library" unless $?.success?
end
