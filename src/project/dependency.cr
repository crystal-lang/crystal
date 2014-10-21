abstract class Dependency
  abstract def install
  property locked_version
  property! name
end
