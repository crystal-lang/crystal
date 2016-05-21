require "../target"

module Crystal
  struct Target::ASMJS::Emscripten < Target
    @triple = "asmjs-unknown-target"
    @endian = "little"
    @pointer_width = "32"
    @os = "emscripten"
    @env = ""
    @vendor = "unknown"
    @data_layout = "e-p:32:32-i64:64-v128:32:128-n32-S128"
    @arch = "asmjs"
    @option = Options.new

    struct Options < Target::Options
      @linker = "emcc"
      @ar = "emar"
      @dynamic_linking = false
      @executables = true
      @executable_suffix = ".js"
    end
  end
end
