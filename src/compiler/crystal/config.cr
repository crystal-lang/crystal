module Crystal
  module Config
    def self.path : String
      {{ env("CRYSTAL_CONFIG_PATH") || "" }}
    end

    def self.version : String
      {% begin %}
        {% version = env("CRYSTAL_CONFIG_VERSION") || raise "Missing required environment variable CRYSTAL_CONFIG_VERSION" %}
        {% compare_versions(version, "0.0.0") %}
        {{ version }}
      {% end %}
    end

    def self.build_commit : String?
      commit = {{ env("CRYSTAL_CONFIG_COMMIT") }}
      return if commit.try &.empty?
      commit
    end

    def self.llvm_version
      LibLLVM::VERSION
    end

    def self.description
      sha = build_commit
      formatted_sha = "[#{sha}] " if sha
      <<-DOC
        Crystal #{version} #{formatted_sha}(#{date})

        LLVM: #{llvm_version}
        Default target: #{self.default_target_triple}
        DOC
    end

    def self.date
      {{ `date "+%Y-%m-%d"`.stringify.chomp }}
    end

    def self.default_target_triple
      {{env("CRYSTAL_CONFIG_TARGET")}} || LLVM.default_target_triple
    end
  end
end
