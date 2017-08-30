require "./system/unix/hostname"

{% if flag?(:freebsd) || flag?(:openbsd) %}
  require "./system/unix/sysctl_cpucount"
{% else %}
  # TODO: restrict on flag?(:unix) after crystal > 0.22.0 is released
  require "./system/unix/sysconf_cpucount"
{% end %}
