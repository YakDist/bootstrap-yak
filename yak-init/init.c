#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static void setup_stdio() {
  int fd;

  close(0);
  close(1);
  close(2);

  fd = open("/dev/console", O_RDWR);
  if (fd != 0)
    _exit(1);

  dup2(0, 1);
  dup2(0, 2);
}

static void spawn_shell(void) {
  pid_t pid = fork();

  if (pid < 0) {
    perror("fork");
    return;
  }

  if (pid == 0) {
    if (setpgid(0, 0) == -1) {
      perror("setpgid");
      exit(1);
    }

    if (tcsetpgrp(0, getpid()) == -1) {
      perror("tcsetpgrp");
      exit(1);
    }

    printf("executing bash as root shell :3\n");
    execl("/usr/bin/bash", "/usr/bin/bash", "-l", NULL);
    perror("execl bash");
    exit(1);
  }

  int status;
  if (waitpid(pid, &status, 0) == -1) {
    perror("waitpid");
  }
}

int main() {
  setsid();
  setup_stdio();

  printf("Hello World, mlibc world!\n");
  printf("Yak init is running :~)\n");

  setenv("PATH", "/usr/bin:/usr/sbin:/sbin:/bin", 1);

  chdir("/root");
  setenv("PWD", "/root", 1);

  setenv("HOME", "/root", 1);
  setenv("TERM", "linux", 1);

  if (0 == fork()) {
    for (;;) {
      spawn_shell();
      printf("login shell died... spawning new one\n");
      sleep(1);
    }
  }

  sleep(10000);

  // Reap zombie children
  sigset_t mask, oldmask;
  sigemptyset(&mask);
  sigaddset(&mask, SIGCHLD);
  sigprocmask(SIG_BLOCK, &mask, &oldmask);

  for (;;) {
    while (waitpid(-1, NULL, WNOHANG) > 0)
      asm volatile("");

    sigsuspend(&oldmask);
  }

  return 0;
}
