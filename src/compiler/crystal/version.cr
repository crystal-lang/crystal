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
    uname = system2("uname -a 2>/dev/null")
    platform = uname[0]? ? uname[0].split(" ")[-2..-1].join(" ") : "-"
    "v#{VERSION} #{version_sha} [#{platform}]"
  end
end
