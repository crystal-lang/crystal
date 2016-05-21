require "../target"


module Crystal
  struct Target::X86_64::Apple::Darwin < Target
    triple = "x86_64-apple-darwin"
    endian = "little"
    pointer_width = "64"
    data_layout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
    arch = "x86_64"
    os = "macos"
    env = ""
    vendor = "apple"
  end
end
