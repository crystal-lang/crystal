require "./parser"

# The YAML::Nodes module provides an implementation of an
# in-memory YAML document tree. This tree can be generated
# with the `YAML::Nodes.parse` method or created with a
# `YAML::Nodes::Builder`.
#
# This document tree can then be converted to YAML by
# invoking `to_yaml` on the document object.
module YAML::Nodes
  # Parses a `String` or `IO` into a `YAML::Nodes::Document`.
  def self.parse(string_or_io : String | IO) : Document
    Parser.new string_or_io, &.parse
  end

  # Parses a `String` or `IO` into multiple `YAML::Nodes::Document`s.
  def self.parse_all(string_or_io : String | IO) : Array(Document)
    Parser.new string_or_io, &.parse_all
  end
end
