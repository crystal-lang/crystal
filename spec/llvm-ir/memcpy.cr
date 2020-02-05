lib LibMylib
  struct Foo
    x : Int64
    y : Int64
  end
end

a = 1
f = ->(s : LibMylib::Foo) {
  a
}

s = LibMylib::Foo.new
f.call(s)

# X64: ctx_is_null:
# X64: [[SRC:%.*]] = bitcast { i64, i64 }* {{%[0-9]+}} to i8*
# X64-NEXT: [[PTR:%.*]] = getelementptr inbounds %"struct.LibMylib::Foo", %"struct.LibMylib::Foo"* %s, i32 0, i32 0
# X64-NEXT: [[DEST:%.*]] = bitcast i64* {{.*}}[[PTR]] to i8*
# X64-NEXT: call void @llvm.memcpy.p0i8.p0i8.i64(i8* align 8 {{.*}}[[SRC]], i8* align 8 {{.*}}[[DEST]], i64 16, i1 false)
