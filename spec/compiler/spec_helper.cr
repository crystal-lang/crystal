require "../spec_helper"
require "../support/tempfile"

def compiler_datapath(*components)
  File.join("spec", "compiler", "data", *components)
end
