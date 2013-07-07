class VirtualFile
  attr_reader :macro
  attr_reader :source

  def initialize(macro, source)
    @macro = macro
    @source = source
  end

  def to_s
    "expanded macro"
  end
end