module Crystal
  module Config
    PATH    = {{ env("CRYSTAL_CONFIG_PATH") || "" }}
    VERSION = {{ env("CRYSTAL_CONFIG_VERSION") || `(git describe --tags --long 2>/dev/null)`.stringify.chomp }}

    def self.path
      PATH
    end

    def self.version
      VERSION
    end

    def self.description
      tag, sha = tag_and_sha
      if sha
        "Crystal #{tag} [#{sha}] (#{date})"
      else
        "Crystal #{tag} (#{date})"
      end
    end

    def self.tag_and_sha
      pieces = version.split("-")
      tag = pieces[0]? || "?"
      sha = pieces[2]?
      if sha
        sha = sha[1..-1] if sha.starts_with? 'g'
      end
      {tag, sha}
    end

    def self.date
      {{ `date "+%Y-%m-%d"`.stringify.chomp }}
    end
  end
end
