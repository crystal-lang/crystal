require "spec"
require "./support/expectations"
require "../support/tempfile"

CRYSTAL_BIN = ENV.fetch("CRYSTAL_SPEC_COMPILER_BIN") { "#{Dir.current}/bin/crystal" }

def crystal
  CRYSTAL_BIN
end

def fixture_path(name : String)
  File.expand_path(File.join(__DIR__, "fixtures", name))
end
