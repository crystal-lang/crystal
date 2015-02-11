require "spec"
require "signal"

describe "Signal" do
  typeof(Signal.trap(Signal::PIPE, Signal::DEFAULT))
  typeof(Signal.trap(Signal::PIPE, Signal::IGNORE))
  typeof(Signal.trap(Signal::PIPE) { 1 })
end
