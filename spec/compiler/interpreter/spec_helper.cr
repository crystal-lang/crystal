{% skip_file if flag?(:without_interpreter) %}
require "../spec_helper"

def interpret(code, *, prelude = "primitives")
  context, value = interpret_with_context(code, prelude: prelude)
  value.value
end

def interpret_with_context(code, *, prelude = "primitives")
  repl = Crystal::Repl.new
  repl.prelude = prelude

  # We disable the GC for programs that use the prelude because
  # finalizers might kick off after the Context has been finalized,
  # leading to segfaults.
  # This is a bit tricky to solve: the finalizers will run once the
  # context has been destroyed (it's memory is no longer allocated
  # so the objects in the program won't be referenced anymore),
  # but for finalizers to be able to run the context needs to be
  # there! :/
  code = "GC.disable\n#{code}" if prelude == "prelude"

  value = repl.run_code(code)
  {repl.context, value}
end
