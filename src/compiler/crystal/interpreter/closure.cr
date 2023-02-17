require "./repl"

module Crystal::Repl::Closure
  # The variable name for closures allocated in a context
  VAR_NAME = ".closure_var"

  # If a closure needs to be allocated, but we are in the context
  # of a proc literal that also receives closure data in its hidden
  # pointer, we declare that argument as ARG_NAME, and we copy
  # that pointre into VAR_NAME.
  ARG_NAME = ".closure_arg"
end
