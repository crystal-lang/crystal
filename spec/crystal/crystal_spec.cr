#!/usr/bin/env bin/crystal -run
require "spec"
$spec_manual_results = true

class Bool
  def bool
    Crystal::BoolLiteral.new self
  end
end

class Int
  def int
    Crystal::IntLiteral.new self.to_s
  end

  def long
    Crystal::LongLiteral.new self.to_s
  end
end

class Float
  def float
    Crystal::FloatLiteral.new self.to_s
  end
end

require "spec/**"

spec_results