module Crystal
  module Config
    def self.path
      {{env("CRYSTAL_CONFIG_PATH") || ""}}
    end

    def self.version
      {{ read_file("#{__DIR__}/../../VERSION").chomp }}
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
      @@default_target ||= begin
        target = Crystal::Codegen::Target.new({{env("CRYSTAL_CONFIG_TARGET")}} || LLVM.default_target_triple)

        if target.linux?
          # The statically linked linux binary runs as well on linux-gnu as
          # on linux-musl, but the default target needs to match the C
          # library used on the current system.
          # This can be automatically detected from the output of `ldd --version`
          # in order to use the appropriate environment target.
          default_libc = target.gnu? ? "-gnu" : "-musl"

          target = Crystal::Codegen::Target.new(target.to_s.sub(default_libc, "-#{runtime_libc}"))
        end

        target
      end
    end

    private def self.runtime_libc
      ldd_version = String.build do |io|
        Process.run("ldd", {"--version"}, output: io, error: io)
      rescue Errno
        # In case of an error (eg. `ldd` not available), we assume it's gnu.
        return "gnu"
      end

      if ldd_version.starts_with?("musl")
        "musl"
      else
        "gnu"
      end
    end

    def self.library_path
      {{env("CRYSTAL_CONFIG_LIBRARY_PATH") || ""}}
    end
  end
end
