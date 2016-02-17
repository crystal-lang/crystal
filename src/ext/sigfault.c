#include <signal.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

void __crystal_sigfault_handler(int sig, void *addr);

void sigfault_handler(int sig, siginfo_t *info, void *data) {
  __crystal_sigfault_handler(sig, info->si_addr);
}

void setup_sigfault_handler() {
  stack_t altstack;
  struct sigaction action;

  altstack.ss_sp = malloc(SIGSTKSZ);
  altstack.ss_size = SIGSTKSZ;
  altstack.ss_flags = 0;
  sigaltstack(&altstack, NULL);

  action.sa_flags = SA_ONSTACK | SA_SIGINFO;
  action.sa_sigaction = &sigfault_handler;

  sigaction(SIGSEGV, &action, NULL);
  sigaction(SIGBUS, &action, NULL);
}
