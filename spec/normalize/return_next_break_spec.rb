require 'spec_helper'

describe 'Normalize: return next break' do
  it "removes nodes after return" do
    assert_normalize "return 1; 2", "return 1"
  end

  it "doesn't remove after return when there's an unless" do
    assert_normalize "return 1 unless 2; 3", "if 2\nelse\n  return 1\nend\n3"
  end

  it "removes nodes after next" do
    assert_normalize "next 1; 2", "next 1"
  end

  it "removes nodes after break" do
    assert_normalize "break 1; 2", "break 1"
  end

  it "removes nodes after if that returns in both branches" do
    assert_normalize "if true; break; else; return; end; 1", "if true\n  break\nelse\n  return\nend"
  end

  it "doesn't remove nodes after if that returns in one branch" do
    assert_normalize "if true; 1; else; return; end; 1", "if true\n  1\nelse\n  return\nend\n1"
  end
end
