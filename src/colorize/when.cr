# `When` is a policy to output escape sequence.
enum Colorize::When
  # Output escape sequence if given *io* is TTY.
  Auto

  # Always output escape sequence even if given *io* is not TTY.
  Always

  # Not output escape sequence even if given *io* is TTY.
  Never

  # Return `true` when given *io* can output escape sequence on this policy.
  # See `Auto`, `Always` and `Never`.
  def output_escape_sequence?(io)
    always? || auto? && io.responds_to?(:tty?) && io.tty?
  end
end
