module Crystal
  def self.version_tag; "unknown"; end
  def self.version_sha; "."; end
  def self.version_patch; "0"; end

  def self.dump_version
    describe = system2("git describe --tags --long 2>/dev/null")[0]? || "."
    tag, patch, sha = describe.split("-")
    
    File.open(__DIR__ + "/version_generated.cr", "w") do |f|
      f.puts "module Crystal"
      f.puts "  def self.version_tag; \"#{tag}\"; end"
      f.puts "  def self.version_sha; \"#{sha}\"; end"
      f.puts "  def self.version_patch; \"#{patch}\"; end"
      f.puts "end"
    end
  rescue
  end

  def self.version_string
    uname = system2("uname -s -m 2>/dev/null")[0]? || ""
    "v#{version_tag}-p#{version_patch} #{version_sha} [#{uname}]"
  end
end
