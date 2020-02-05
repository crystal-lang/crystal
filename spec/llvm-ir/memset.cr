Pointer(UInt8).malloc(10)

# X32: [[PTR:%.*]] = call i8* @malloc(i32 trunc ([[SIZE:.*]]) to i32))
# X32-NEXT: call void @llvm.memset.p0i8.i32(i8* align 4 {{.*}}[[PTR]], i8 0, i32 trunc ({{.*}}[[SIZE]]) to i32), i1 false)

# X64: [[PTR:%.*]] = call i8* @malloc([[SIZE:.*]])
# X64-NEXT: call void @llvm.memset.p0i8.i64(i8* align 4 {{.*}}[[PTR]], i8 0, {{.*}}[[SIZE]], i1 false)
