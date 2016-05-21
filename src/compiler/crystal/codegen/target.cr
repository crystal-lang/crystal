abstract struct Crystal::Target
  @triple: String?
  @endian: String?
  @pointer_width: String?
  @os: String?
  @env: String?
  @vendor: String?
  @arch: String?
  @data_layout: String?
  @option: Options?
end

abstract struct Crystal::Target::Options
  @linker: String = ENV["CC"]? || "cc"
  @ar: String = ENV["AR"]? || "ar"
  @dynamic_linking: Bool = false
  @executables: Bool = false
  @executable_suffix: String = ""
end
