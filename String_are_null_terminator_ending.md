String#to_unsafe
def to_unsafe : Pointer(UInt8)
This returns a pointer to the internal, null terminated (\0-terminated) byte buffer of the string. This is useful when interoperating with C libraries that expect C-style strings.
More information:
•	The returned pointer references the underlying UTF-8 encoded bytes of the string, followed by a null byte (\0) used as a terminator.
•	This null terminator is automatically maintained by the crystal runtime and ensures compatibility with C APIs that expect strings ending in \0.
•	The pointer is only valid while the original string object exists. If the string is modified or garbage collected, the pointer becomes invalid.
Note:
Although crystal strings are null-terminated, they can contain \0 bytes anywhere within their content: 
Ex:
str = “race\0car”
str.bytesize # => 8
str.size # => 8

It can be seen that \0 is present at index 4 and then length of the string is 8.
C functions that rely on the first \0 to mark the end of a string will see only the part up to the first null byte:

str = “race\0car”
c_str = str.to_unsafe
puts String.new(c_str) # => “race”



