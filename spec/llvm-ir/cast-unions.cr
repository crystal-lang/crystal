(1 || true).as(Int32 | Bool | UInt8[12])

# X64: [[DEST:%.*]] = bitcast %"(Bool | Int32 | StaticArray(UInt8, 12))"* {{.*}} to %"(Bool | Int32)"*
# X64-NEXT: [[SRC:%.*]] = load %"(Bool | Int32)", %"(Bool | Int32)"* {{.*}}
# X64-NEXT: store %"(Bool | Int32)" {{.*}}[[SRC]], %"(Bool | Int32)"* {{.*}}[[DEST]]
