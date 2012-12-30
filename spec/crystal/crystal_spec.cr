#!/usr/bin/env bin/crystal -run
require "spec"
$spec_manual_results = true

class Bool
  def bool
    Crystal::BoolLiteral.new self
  end
end

require "spec/**"

spec_results