require "spec"

ifdef evented
else
  {% raise "must run with -Devented flag" %}
end
