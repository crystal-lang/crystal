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
      return {next_patch({{Crystal::VERSION}}), nil} if git_version.empty?

      # Shallow clone with no tag in reach: abcd123
      # We assume being compiled with the latest released compiler
      return {"#{next_patch({{Crystal::VERSION}})}-c?", git_version} unless git_version.includes? '-'

      # On release: 0.0.0-0-gabcd123
      # Ahead of last release: 0.0.0-42-gabcd123
      tag, commits, sha = git_version.split('-')
      sha = sha[1..-1] # Strip g
      # Increase patch and reappend count of commits since release unless we hit it exactly
      tag = "#{next_patch(tag)}-c#{commits}" unless commits == "0"

      # If the build is dont on exact tag, use the tag as version as is
      {tag, sha}
    end

    private def self.next_patch(version : String) : String
      m = version.match /^(\d+)\.(\d+)\.(\d+)(-([\w\.]+))?(\+(\w+))??$/
      if m
        major = m[1].to_i
        minor = m[2].to_i
        patch = m[3].to_i
        "#{major}.#{minor}.#{patch + 1}"
      else
        # if the version does not match a semver let it go through
        # might happen if the tag is not a M.m.p
        version
      end
    end

    def self.date
      {{ env("CRYSTAL_CONFIG_BUILD_DATE") || `date "+%Y-%m-%d"`.stringify.chomp }}
    end

    def self.default_target_triple
      {{env("CRYSTAL_CONFIG_TARGET")}} || LLVM.default_target_triple
    end
  end
end
