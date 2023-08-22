require "spec"

SPEC_CRYSTAL_LOADER_LIB_PATH = File.join(SPEC_TEMPFILE_PATH, "loader")

def build_c_dynlib(c_filename, target_dir = SPEC_CRYSTAL_LOADER_LIB_PATH)
  o_filename = File.join(target_dir, Crystal::Loader.library_filename(File.basename(c_filename, ".c")))

  {% if flag?(:msvc) %}
    o_basename = o_filename.rchop(".lib")
    `#{ENV["CC"]? || "cl.exe"} /nologo /LD #{Process.quote(c_filename)} #{Process.quote("/Fo#{o_basename}")} #{Process.quote("/Fe#{o_basename}")}`
  {% else %}
    `#{ENV["CC"]? || "cc"} -shared -fvisibility=hidden #{Process.quote(c_filename)} -o #{Process.quote(o_filename)}`
  {% end %}

  raise "BUG: failed to compile dynamic library" unless $?.success?
end
