lib LibC
  fun _CxxThrowException = _CxxThrowException(pExceptionObject : Void*, _ThrowInfo : Void*) : NoReturn
end

module WindowsExt
  @[Primitive(:throw_info)]
  def self.throw_info : Void*
  end
end
