macro compile_time_system(cmd)
  {{ system(cmd).stringify }}
end

module Crystal
  def self.git_describe
    str = compile_time_system("git describe --tags --long 2>/dev/null")
    a = str.split("-")
    tag = a[0]? || "?"
    patch = a[1]? || "0"
    sha = a[2]? ? a[2][1..-1] : "-"
    { tag, patch, sha }
  end

  def self.version_string
    uname = system2("uname -ms 2>/dev/null")[0]? || "-"
    tag, patch, sha = git_describe
    "v#{tag}p#{patch} #{sha} [#{uname}]"
  end
end
