abstract class Crystal::Dependency
  abstract def install
  property locked_version
  property name

  def initialize(@name)
    case @name
    when /^crystal(?:_|-)(.*)$/
      @name = $1
    when /^(.*)(?:\_|-)crystal$/
      @name = $1
    when /^(.*)\.cr$/
      @name = $1
    end
  end
end
