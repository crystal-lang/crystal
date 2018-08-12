#include <signal.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

void __crystal_sigfault_handler(int sig, void *addr);
void __crystal_sigalarm_handler(int sig);

static void sigfault_handler(int sig, siginfo_t *info, void *data) {
  __crystal_sigfault_handler(sig, info->si_addr);
}

static void alarm_handler(int sig, siginfo_t *info, void *data) {
  __crystal_sigalarm_handler(sig);
}

void setup_sigfault_handler() {
  stack_t altstack;
  struct sigaction action;

  altstack.ss_sp = malloc(SIGSTKSZ);
  altstack.ss_size = SIGSTKSZ;
  altstack.ss_flags = 0;
  sigaltstack(&altstack, NULL);

  sigemptyset(&action.sa_mask);
  action.sa_flags = SA_ONSTACK | SA_SIGINFO;
  action.sa_sigaction = &sigfault_handler;

  sigaction(SIGSEGV, &action, NULL);
  sigaction(SIGBUS, &action, NULL);
}

void setup_alarm_handler() {
  struct sigaction action;

  sigemptyset(&action.sa_mask);
  action.sa_flags = SA_NODEFER;
  action.sa_sigaction = &alarm_handler;

  sigaction(SIGALRM, &action, NULL);
}
