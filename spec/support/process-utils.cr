# Process utils are helper programs for testing process spawn behaviour.
# They are defined in spec/support/process-utils.cr which
# we require here in order to build them into the spec executable.
# We then call the spec executable with "pu" as first argument followed
# by the command name.
# This mechanism doesn't work when running in the interpreter, because
# there is no spec executable we could call again. Instead, we need a
# to build process utils into a separate executable `crystal-pu` which
# we can call from the interpreter.
# This approach would also work for compiled specs, but building it into
# the executable is simpler and does not require a separate build step.

{% unless flag?(:interpreted) %}
  require "./process-utils-exe.cr"
{% end %}

module ProcessUtils
  EXE = {% if flag?(:interpreted) %}
    "#{Process.executable_path.not_nil!.rchop(".exe")}-pu#{".exe" if {{ flag?(:win32) }}}"
  {% else %}
          Process.executable_path.not_nil!
        {% end %}
end
