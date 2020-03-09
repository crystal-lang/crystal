# This is the file that is compiled to generate the
# executable for the compiler.

{% raise("Please use `make crystal` to build the compiler, or set the i_know_what_im_doing flag if you know what you're doing") unless env("CRYSTAL_HAS_WRAPPER") || flag?("i_know_what_im_doing") %}

require "log"
require "./crystal/**"

Log.setup_from_env(
  level: ENV.fetch("CRYSTAL_LOG_LEVEL", "WARNING"),
  sources: ENV.fetch("CRYSTAL_LOG_SOURCES", "crystal.*")
)

Crystal::Command.run
