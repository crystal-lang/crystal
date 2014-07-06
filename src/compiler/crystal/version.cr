module Crystal
  def self.version_string
    str = {{ system(%((git describe --tags --long 2>/dev/null) || echo "?-?-?")).stringify }}
    build_date = {{ system("date -u").stringify }}
    a = str.split("-")
    tag = a[0]? || "?"
    patch = a[1]? || "0"
    sha = a[2]? ? a[2][1..-1] : "-"
    "#{tag}-p#{patch} [#{sha}] (#{build_date})"
  end
end
