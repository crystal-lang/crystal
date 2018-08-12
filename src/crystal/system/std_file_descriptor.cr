# Using `O_NONBLOCK` can lead to unexpected behavior when a file descriptor is
# shared between processes, which is always the case for STDIN, STDOUT and
# STDERR. Other processes may not be resilient to file descriptors having
# O_NONBLOCK set and may even change it to return back to blocking —which can
# happen when spawning a child process that inherits STDIN for example.
#
# A solution (hack) is to have blocking syscalls but arm timers to send the ALRM
# signal that will cause blocking syscalls to fail and return EINTR.
#
# WARNING: this affects all interuptible syscalls! See signal(7) for the full
# list.
#
# See:
# - https://github.com/crystal-lang/crystal/issues/3674
# - http://cr.yp.to/unix/nonblock.html

{% if flag?(:darwin) || flag?(:openbsd) %}
  require "./unix/std_file_descriptor_setitimer"
{% elsif flag?(:unix) %}
  require "./unix/std_file_descriptor_sigalrm"
{% end %}
