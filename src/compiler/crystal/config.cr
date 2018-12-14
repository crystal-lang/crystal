module Crystal
  module Config
    def self.path
      {{env("CRYSTAL_CONFIG_PATH") || ""}}
    end

    def self.version
      {% if flag?(:windows) %}
        {{ `type #{__DIR__}/../../../VERSION`.stringify.chomp }}
      {% else %}
        {{ `cat #{__DIR__}/../../../VERSION`.stringify.chomp }}
      {% end %}
    end

    def self.llvm_version
      LibLLVM::VERSION
    end

    def self.description
      formatted_sha = "[#{build_commit}] " if build_commit
      <<-DOC
        Crystal #{version} #{formatted_sha}(#{date})

        LLVM: #{llvm_version}
        Default target: #{self.default_target_triple}
        DOC
    end

    def self.build_commit
      sha = {{ env("CRYSTAL_CONFIG_BUILD_COMMIT") || "" }}
      sha = nil if sha.empty?

      sha
    end

    def self.date
      time = {{ (env("SOURCE_DATE_EPOCH") || `date +%s`).to_i }}
      Time.unix(time).to_s("%Y-%m-%d")
    end

    def self.default_target_triple
      {{env("CRYSTAL_CONFIG_TARGET")}} || LLVM.default_target_triple
    end
  end
end
