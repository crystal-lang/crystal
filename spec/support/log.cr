require "log"
require "log/spec"

# Turn off logging in specs
def log_setup_on_specs
  Log.setup(:none)
end

log_setup_on_specs
