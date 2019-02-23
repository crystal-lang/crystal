module Crystal
  module Config
    def self.path
      {{env("CRYSTAL_CONFIG_PATH") || ""}}
    end

    def self.version
      {{ read_file("#{__DIR__}/../../../VERSION").chomp }}
    end

    def self.llvm_version
      LibLLVM::VERSION
    end

    def self.description
      formatted_sha = "[#{build_commit}] " if build_commit
      <<-DOC
        Crystal #{version} #{formatted_sha}(#{date})

        LLVM: #{llvm_version}
        Default target: #{self.default_target}
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

    @@default_target : Crystal::Codegen::Target?

    def self.default_target : Crystal::Codegen::Target
      @@default_target || begin
        target = Crystal::Codegen::Target.new({{env("CRYSTAL_CONFIG_TARGET")}} || LLVM.default_target_triple)

        if target.linux?
          # The linux binary runs as well on linux-gnu as linux-musl, but the
          # default target needs to match the C library used on the current
          # system.
          # This can be automatically detected from the output of `ldd --version`
          # in order to use the appropriate environment target.
          musl_environment = musl_environment?
          if musl_environment && target.gnu?
            target = Crystal::Codegen::Target.new(target.to_s.sub("-gnu", "-musl"))
          elsif !musl_environment && target.musl?
            target = Crystal::Codegen::Target.new(target.to_s.sub("-musl", "-gnu"))
          end
        end

        @@default_target = target
      end
    end

    private def self.musl_environment?
      ldd_version = String.build do |io|
        Process.new("ldd", ["--version"], output: io, error: io).wait
      rescue Errno
        # In case of an error (for example `ldd` not available), we simply
        # assume it's not musl
        return false
      end

      ldd_version.starts_with?("musl")
    end
  end
end
