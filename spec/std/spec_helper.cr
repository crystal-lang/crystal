require "spec"
require "../support/tempfile"

def datapath(*components)
  File.join("spec", "std", "data", *components)
end
