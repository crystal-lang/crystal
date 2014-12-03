abstract class Crystal::Dependency
  abstract def install
  property locked_version
  property name

  def initialize(@name)
  end
end
