# :nodoc:
struct Crystal::System::Process
end

{% if flag?(:unix) %}
  require "./unix/process"
{% else %}
  {% raise "No Crystal::System::Process implementation available" %}
{% end %}
