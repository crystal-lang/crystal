# This is the file that is compiled to generate the
# executable for the compiler.

{% raise("Please use `make crystal` to build the compiler, or set the i_know_what_im_doing flag if you know what you're doing") unless env("CRYSTAL_HAS_WRAPPER") || flag?("i_know_what_im_doing") %}

{%
  version = "1.2.0"
  raise("Compiling Crystal requires at least version #{version.id} of Crystal. Current version is #{Crystal::VERSION}") if compare_versions(Crystal::VERSION, version.id) < 0
%}

require "log"
require "./requires"

Log.setup_from_env(default_level: :warn, default_sources: "crystal.*")

Crystal::Command.run
