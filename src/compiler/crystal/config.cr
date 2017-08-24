module Crystal
  module Config
    def self.path
      {{env("CRYSTAL_CONFIG_PATH") || ""}}
    end

    def self.version
      version_and_sha.first
    end

    def self.llvm_version
      LibLLVM::VERSION
    end

    def self.description
      version, sha = version_and_sha
      formatted_sha = "[#{sha}] " if sha
      <<-DOC
        Crystal #{version} #{formatted_sha}(#{date})

        LLVM: #{llvm_version}
        Default target: #{self.default_target_triple}
        DOC
    end

    @@version_and_sha : {String, String?}?

    def self.version_and_sha
      @@version_and_sha ||= compute_version_and_sha
    end

    private def self.compute_version_and_sha
      # Set explicitly: 0.0.0, ci, HEAD, whatever
      config_version = {{env("CRYSTAL_CONFIG_VERSION")}}
      return {config_version, nil} if config_version

      git_version = {{`(git describe --tags --long --always 2>/dev/null) || true`.stringify.chomp}}

      # Failed git and no explicit version set: ""
      # We inherit the version of the compiler building us for now.
      return { {{Crystal::VERSION}}, nil } if git_version.empty?

      # Shallow clone with no tag in reach: abcd123
      # We assume being compiled with the latest released compiler
      return {"#{{{Crystal::VERSION}}}+?", git_version} unless git_version.includes? '-'

      # On release: 0.0.0-0-gabcd123
      # Ahead of last release: 0.0.0-42-gabcd123
      tag, commits, sha = git_version.split("-")
      sha = sha[1..-1]                                # Strip g
      tag = "#{tag}+#{commits}" unless commits == "0" # Reappend commits since release unless we hit it exactly

      {tag, sha}
    end

    def self.date
      {{ `date "+%Y-%m-%d"`.stringify.chomp }}
    end

    def self.default_target_triple
      {{env("CRYSTAL_CONFIG_TARGET")}} || LLVM.default_target_triple
    end
  end
end
