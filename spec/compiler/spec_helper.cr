require "../spec_helper"
require "../support/tempfile"

def datapath(*components)
  File.join("spec", "compiler", "data", *components)
end
