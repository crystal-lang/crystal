require "spec"

SPEC_CRYSTAL_LOADER_LIB_PATH = File.join(SPEC_TEMPFILE_PATH, "loader")

def build_c_dynlib(c_filename, target_dir = SPEC_CRYSTAL_LOADER_LIB_PATH)
  o_filename = File.join(target_dir, Crystal::Loader.library_filename(File.basename(c_filename).rchop(".c")))

  {% if flag?(:msvc) %}
    `cl.exe /nologo /LD #{Process.quote(c_filename)} #{Process.quote("/Fo#{o_filename}")}`.should be_truthy
  {% else %}
    `#{ENV["CC"]? || "cc"} -shared #{Process.quote(c_filename)} -o #{Process.quote(o_filename)}`.should be_truthy
  {% end %}
end
