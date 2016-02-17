require "./config"

def Crystal.version_string
  build_date = {{ `date -u`.stringify.chomp }}
  version = Crystal::Config::VERSION
  pieces = version.split("-")
  tag = pieces[0]? || "?"
  if sha = pieces[2]?
    sha = sha[1..-1] if sha.starts_with? 'g'
    "#{tag} [#{sha}] (#{build_date})"
  else
    "#{tag} (#{build_date})"
  end
end
