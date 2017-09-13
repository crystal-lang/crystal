class Crystal::Program
  @flags : Set(String)?

  # Returns the flags for this program. By default these
  # are computed from the target triple (for example x86_64,
  # darwin, linux, etc.), but can be overwritten with `flags=`
  # and also added with the `-D` command line argument.
  #
  # See `Compiler#flags`.
  def flags
    @flags ||= parse_flags(target_machine.triple.split('-'))
  end

  # Overrides the default flags with the given ones.
  def flags=(flags : String)
    @flags = parse_flags(flags.split)
  end

  # Returns `true` if *name* is in the program's flags.
  def has_flag?(name : String)
    flags.includes?(name)
  end

  def bits64?
    has_flag?("bits64")
  end

  private def parse_flags(flags_name)
    set = flags_name.map(&.downcase).to_set
    set.add "darwin" if set.any?(&.starts_with?("macosx")) || set.any?(&.starts_with?("darwin"))
    set.add "freebsd" if set.any?(&.starts_with?("freebsd"))
    set.add "openbsd" if set.any?(&.starts_with?("openbsd"))
    set.add "unix" if set.any? { |flag| %w(cygnus darwin freebsd linux openbsd).includes?(flag) }
    set.add "win32" if set.any?(&.starts_with?("windows")) && set.any? { |flag| %w(gnu msvc).includes?(flag) }

    set.add "x86_64" if set.any?(&.starts_with?("amd64"))
    set.add "i686" if set.any? { |flag| %w(i586 i486 i386).includes?(flag) }

    if set.any?(&.starts_with?("arm"))
      set.add "arm"
      set.add "armhf" if set.includes?("gnueabihf")
    end

    if set.includes?("x86_64") || set.includes?("aarch64")
      set.add "bits64"
    else
      set.add "bits32"
    end

    set
  end
end
