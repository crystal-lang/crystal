class VirtualFile
  attr_reader :macro
  attr_reader :source

  def initialize(macro, source)
    @macro = macro
    @source = source
  end
end