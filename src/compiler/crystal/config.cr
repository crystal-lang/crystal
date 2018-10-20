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
      config_version = {% if flag?(:windows) %}
                       {{ `type #{__DIR__}/../../../VERSION`.stringify.chomp }}
                       {% else %}
                       {{ `cat #{__DIR__}/../../../VERSION`.stringify.chomp }}
                       {% end %}
      git_describe = {{ `(git describe --tags --long --always 2>/dev/null) || true`.stringify.chomp }}

      # git_describe: 0.0.0-42-gabcd123, 0.0.0-rc1-42-gabcd123
      # sha: strip g from the last part if possible
      last_dash = git_describe.rindex('-')
      sha = last_dash ? git_describe[last_dash + 2..-1] : nil

      {config_version, sha}
    end

    def self.date
      {{ env("CRYSTAL_CONFIG_BUILD_DATE") || `date "+%Y-%m-%d"`.stringify.chomp }}
    end

    def self.default_target_triple
      {{env("CRYSTAL_CONFIG_TARGET")}} || LLVM.default_target_triple
    end
  end
end
