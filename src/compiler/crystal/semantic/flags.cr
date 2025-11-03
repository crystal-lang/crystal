class Crystal::Program
  @flags : Set(String)?
  @host_flags : Set(String)?

  # Returns the flags for this program. By default these
  # are computed from the target triple (for example x86_64,
  # darwin, linux, etc.), but can be overwritten with `flags=`
  # and also added with the `-D` command line argument.
  #
  # See `Compiler#flags`.
  def flags
    @flags ||= flags_for_target(codegen_target)
  end

  def host_flags
    @host_flags ||= flags_for_target(Config.host_target)
  end

  # Returns `true` if *name* is in the program's flags.
  def has_flag?(name : String)
    flags.includes?(name)
  end

  # Returns the value of a flag in the format `"#{key}=#{value}"`.
  # Or `true` if the flags contain `key`.
  def flag_value(name : String) : String | Bool
    self.class.flag_value(flags_ary, name)
  end

  # Returns the value of a host flag in the format `"#{key}=#{value}"`.
  # Or `true` if the host flags contain `key`.
  def host_flag_value(name : String) : String | Bool
    self.class.flag_value(host_flags_ary, name)
  end

  private getter flags_ary : Array(String) do
    flags.to_a
  end
  private getter host_flags_ary : Array(String) do
    host_flags.to_a
  end

  def self.flag_value(flags, name)
    flags.reverse_each do |flag|
      # Easy test to skip items that wouldn't match anyway
      next unless flag.starts_with?(name)

      key, assign, value = flag.partition("=")
      if key == name
        return assign == "=" ? value : true
      end
    end

    false
  end

  def bits64?
    codegen_target.pointer_bit_width == 64
  end

  def size_bit_width
    codegen_target.size_bit_width
  end

  private def flags_for_target(target)
    flags = Set(String).new

    flags.add target.architecture
    flags.add target.vendor
    flags.concat target.environment_parts

    flags.add "bits#{target.pointer_bit_width}"

    flags.add "armhf" if target.armhf?

    flags.add "unix" if target.unix?
    flags.add "win32" if target.win32?

    flags.add "darwin" if target.macos?
    if target.freebsd?
      flags.add "freebsd"
      flags.add "freebsd#{target.freebsd_version}"
    end
    flags.add "netbsd" if target.netbsd?

    if target.openbsd?
      flags.add "openbsd"

      case target.architecture
      when "aarch64"
        flags.add "branch-protection=bti" unless flags.any?(&.starts_with?("branch-protection="))
      when "x86_64", "i386"
        flags.add "cf-protection=branch" unless flags.any?(&.starts_with?("cf-protection="))
      end
    end

    flags.add "dragonfly" if target.dragonfly?
    flags.add "solaris" if target.solaris?
    flags.add "android" if target.android?

    flags.add "bsd" if target.bsd?

    if target.avr? && (cpu = target_machine.cpu.presence)
      flags.add cpu
    end

    flags
  end
end
