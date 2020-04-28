class Crystal::Program
  @flags : Set(String)?

  # Returns the flags for this program. By default these
  # are computed from the target triple (for example x86_64,
  # darwin, linux, etc.), but can be overwritten with `flags=`
  # and also added with the `-D` command line argument.
  #
  # See `Compiler#flags`.
  def flags
    @flags ||= flags_for_target(codegen_target)
  end

  # Returns `true` if *name* is in the program's flags.
  def has_flag?(name : String)
    flags.includes?(name)
  end

  def bits64?
    codegen_target.pointer_bit_width == 64
  end

  private def flags_for_target(codegen_target)
    flags = Set(String).new

    flags.add codegen_target.architecture
    flags.add codegen_target.vendor
    flags.concat codegen_target.environment_parts

    flags.add "bits#{codegen_target.pointer_bit_width}"

    flags.add "armhf" if codegen_target.armhf?

    flags.add "unix" if codegen_target.unix?
    flags.add "win32" if codegen_target.win32?

    flags.add "darwin" if codegen_target.macos?
    if codegen_target.freebsd?
      flags.add "freebsd"
      flags.add "freebsd#{codegen_target.freebsd_version}"
    end
    flags.add "openbsd" if codegen_target.openbsd?
    flags.add "dragonfly" if codegen_target.dragonfly?

    flags.add "bsd" if codegen_target.bsd?

    flags
  end
end
