require "./unix/hostname"

{% if flag?(:freebsd) || flag?(:openbsd) %}
  require "./unix/sysctl_cpucount"
{% else %}
  # TODO: restrict on flag?(:unix) after crystal > 0.22.0 is released
  require "./unix/sysconf_cpucount"
{% end %}
