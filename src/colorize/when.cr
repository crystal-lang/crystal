# `When` is a policy to output escape sequence.
enum Colorize::When
  # Output escape sequence if given *io* is TTY.
  Auto

  # Always output escape sequence even if given *io* is not TTY.
  Always

  # Not output escape sequence even if given *io* is TTY.
  Never

  # Return `true` if given *io* is colorizable on this policy.
  # See `Auto`, `Always` and `Never`.
  def colorizable_io?(io)
    always? || auto? && io.responds_to?(:tty?) && io.tty?
  end
end
