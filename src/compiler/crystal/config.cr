require "./codegen/target"

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
      String.build do |io|
        io << "Crystal " << version
        io << " [" << build_commit << "]" if build_commit
        io << " (" << date << ")" unless date.empty?

        io << "\n\nThe compiler was not built in release mode." unless release_mode?

        io << "\n\nLLVM: " << llvm_version
        io << "\nDefault target: " << host_target
        io << "\n"
      end
    end

    def self.build_commit
      sha = {{ env("CRYSTAL_CONFIG_BUILD_COMMIT") || "" }}
      sha = nil if sha.empty?

      sha
    end

    def self.date
      source_date_epoch = {{ (t = env("SOURCE_DATE_EPOCH")) && !t.empty? ? t.to_i : nil }}
      if source_date_epoch
        Time.unix(source_date_epoch).to_s("%Y-%m-%d")
      else
        ""
      end
    end

    def self.release_mode?
      {{ flag?(:release) }}
    end

    @@host_target : Crystal::Codegen::Target?

    def self.host_target : Crystal::Codegen::Target
      @@host_target ||= begin
        target = Crystal::Codegen::Target.new({{env("CRYSTAL_CONFIG_TARGET")}} || LLVM.default_target_triple)

        if target.linux?
          # The statically linked linux binary runs as well on linux-gnu as
          # on linux-musl, but the default target needs to match the C
          # library used on the current system.
          # This can be automatically detected from the output of `ldd --version`
          # in order to use the appropriate environment target.
          default_libc = target.gnu? ? "-gnu" : "-musl"

          target = Crystal::Codegen::Target.new(target.to_s.sub(default_libc, "-#{linux_runtime_libc}"))
        end

        target
      end
    end

    def self.linux_runtime_libc
      ldd_version = String.build do |io|
        Process.run("ldd", {"--version"}, output: io, error: io)
      rescue
        # In case of an error (eg. `ldd` not available), we assume it's gnu.
        return "gnu"
      end

      # Generally, `ldd --version` should print `musl`.
      # But there is a bug in alpine 3.10 which breaks `ldd --version`.
      # But detection still works with `-musl`, and it doesn't do harm in other
      # cases.
      if ldd_version.starts_with?("musl") || ldd_version.includes?("-musl")
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
