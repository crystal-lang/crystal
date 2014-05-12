module Crystal
  VERSION = "0.1"
  def self.version_sha; "."; end

  def self.dump_version
    rev = system2("git rev-parse --short HEAD 2>/dev/null")
    sha = rev[0]? || "-"
    
    File.open(__DIR__ + "/version_generated.cr", "w") do |f|
      f.puts "module Crystal"
      f.puts "  def self.version_sha; \"#{sha}\"; end"
      f.puts "end"
    end
  end

  def self.version_string
    machine = system2("uname -m 2>/dev/null")[0]? || "-"
    system = system2("uname -s 2>/dev/null")[0]? || "-"
    "v#{VERSION} #{version_sha} [#{system} #{machine}]"
  end
end
