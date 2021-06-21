{% skip_file unless flag?(:unix) %}

{% if flag?(:x86_64) %}
  # :nodoc:
  @[Naked]
  fun __crystal_probe_stack
    asm("
    mov %rax, %r11
    cmp $$0x1000, %r11  // check %r11 first, otherwise segmentation fault occurs.
    jna 2f
  1:
    sub $$0x1000, %rsp
    test %rsp, 8(%rsp)
    sub $$0x1000, %r11
    cmp $$0x1000, %r11
    ja 1b
  2:
    sub %r11, %rsp
    test %rsp, 8(%rsp)
    add %rax, %rsp
    ret
    ")
  end
{% elsif flag?(:i386) %}
  # :nodoc:
  @[Naked]
  fun __crystal_probe_stack
    asm("
    push %ecx
    mov %eax, %ecx
    cmp $$0x1000, %ecx
    jna 2f
  1:
    sub $$0x1000, %esp
    test %esp, 8(%esp)
    sub $$0x1000, %ecx
    cmp $$0x1000, %ecx
    ja 1b
  2:
    sub %ecx, %esp
    test %esp, 8(%esp)
    add %eax, %esp
    pop %ecx
    ret
    ")
  end
{% end %}
