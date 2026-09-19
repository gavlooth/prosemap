// Exec
// ====
// Run /bin/sh -c with bounded stdout. The blocking pipe pump runs on an IO
// worker, so a child cannot stall the evaluator while it waits for input or
// output.

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#ifndef EXEC_READ_CHUNK
#define EXEC_READ_CHUNK 8192u
#endif

typedef struct {
  char*  cmd;
  char*  input;
  size_t input_size;
  size_t input_at;
  char*  output;
  size_t output_size;
  size_t output_cap;
  size_t max_output;
  u32    timeout_ms;
} ExecJob;

static void exec_close(int* fd) {
  if (*fd >= 0) {
    close(*fd);
    *fd = -1;
  }
}

static int exec_cloexec(int fd) {
  int flags = fcntl(fd, F_GETFD);
  return flags < 0 ? -1 : fcntl(fd, F_SETFD, flags | FD_CLOEXEC);
}

static int exec_nonblock(int fd) {
  int flags = fcntl(fd, F_GETFL);
  return flags < 0 ? -1 : fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

static int64_t exec_now_ns(void) {
  struct timespec now;
  return clock_gettime(CLOCK_MONOTONIC, &now) == 0
    ? (int64_t)now.tv_sec * 1000000000ll + now.tv_nsec : -1;
}

static int exec_poll_timeout(const ExecJob* job, int64_t deadline) {
  if (job->timeout_ms == 0) {
    return -1;
  }
  int64_t left = deadline - exec_now_ns();
  if (left <= 0) {
    return 0;
  }
  int64_t ms = (left + 999999ll) / 1000000ll;
  return ms > INT_MAX ? INT_MAX : (int)ms;
}

static int exec_append(ExecJob* job, const char* data, size_t size) {
  if (size > job->max_output - job->output_size) {
    return EOVERFLOW;
  }
  size_t need = job->output_size + size;
  if (need > job->output_cap) {
    size_t cap = job->output_cap;
    do {
      size_t next = cap < EXEC_READ_CHUNK ? EXEC_READ_CHUNK : cap * 2;
      cap = next > job->max_output ? job->max_output : next;
    } while (cap < need);
    job->output = io_mem(realloc(job->output, cap));
    job->output_cap = cap;
  }
  memcpy(job->output + job->output_size, data, size);
  job->output_size = need;
  return 0;
}

static void exec_kill_and_reap(pid_t pid) {
  int status;
  if (pid <= 0) {
    return;
  }
  // The child makes its own process group so timeout/overflow also stop a
  // shell command's descendants rather than leaving a pipe reader behind.
  kill(-pid, SIGKILL);
  kill(pid, SIGKILL);
  while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {
  }
}

static void exec_cleanup_child(int* in_fd, int* out_fd, pid_t pid) {
  exec_kill_and_reap(pid);
  exec_close(in_fd);
  exec_close(out_fd);
}

static void exec_consume_sigpipe(void) {
  sigset_t set;
  struct timespec zero = { 0, 0 };
  sigemptyset(&set);
  sigaddset(&set, SIGPIPE);
  while (sigtimedwait(&set, NULL, &zero) < 0 && errno == EINTR) {
  }
}

static void exec_call(IoWork* w) {
  ExecJob* job = (ExecJob*)w->data;
  int in_pipe[2] = { -1, -1 };
  int out_pipe[2] = { -1, -1 };
  int in_fd = -1;
  int out_fd = -1;
  pid_t pid = -1;
  int status = 0;
  int child_done = 0;
  sigset_t pipe_set;
  sigset_t old_mask;
  int sigpipe_blocked = 0;
  int64_t deadline = 0;
  int code = 0;

  if (pipe(in_pipe) < 0 || pipe(out_pipe) < 0
      || exec_cloexec(in_pipe[0]) < 0 || exec_cloexec(in_pipe[1]) < 0
      || exec_cloexec(out_pipe[0]) < 0 || exec_cloexec(out_pipe[1]) < 0) {
    code = errno;
    goto fail;
  }
  pid = fork();
  if (pid < 0) {
    code = errno;
    goto fail;
  }
  if (pid == 0) {
    char* argv[] = { "sh", "-c", job->cmd, NULL };
    extern char** environ;
    setpgid(0, 0);
    if (dup2(in_pipe[0], STDIN_FILENO) < 0
        || dup2(out_pipe[1], STDOUT_FILENO) < 0) {
      _exit(127);
    }
    close(in_pipe[0]);
    close(in_pipe[1]);
    close(out_pipe[0]);
    close(out_pipe[1]);
    execve("/bin/sh", argv, environ);
    _exit(127);
  }

  setpgid(pid, pid);
  exec_close(&in_pipe[0]);
  exec_close(&out_pipe[1]);
  in_fd = in_pipe[1];
  out_fd = out_pipe[0];
  in_pipe[1] = -1;
  out_pipe[0] = -1;
  if (exec_nonblock(in_fd) < 0 || exec_nonblock(out_fd) < 0) {
    code = errno;
    goto fail;
  }
  if (job->input_size == 0) {
    exec_close(&in_fd);
  }
  sigemptyset(&pipe_set);
  sigaddset(&pipe_set, SIGPIPE);
  code = pthread_sigmask(SIG_BLOCK, &pipe_set, &old_mask);
  if (code != 0) {
    goto fail;
  }
  sigpipe_blocked = 1;
  if (job->timeout_ms != 0) {
    int64_t now = exec_now_ns();
    if (now < 0) {
      code = errno;
      goto fail;
    }
    deadline = now + (int64_t)job->timeout_ms * 1000000ll;
  }

  while (in_fd >= 0 || out_fd >= 0 || !child_done) {
    if (!child_done) {
      pid_t got = waitpid(pid, &status, WNOHANG);
      if (got == pid) {
        child_done = 1;
      } else if (got < 0 && errno != EINTR) {
        code = errno;
        goto fail;
      }
    }
    if (child_done && in_fd >= 0) {
      exec_close(&in_fd);
    }
    if (in_fd < 0 && out_fd < 0) {
      if (child_done) {
        break;
      }
      if (job->timeout_ms == 0) {
        pid_t got;
        do {
          got = waitpid(pid, &status, 0);
        } while (got < 0 && errno == EINTR);
        if (got != pid) {
          code = errno == 0 ? ECHILD : errno;
          goto fail;
        }
        child_done = 1;
        continue;
      }
      int wait_ms = exec_poll_timeout(job, deadline);
      if (wait_ms == 0 || poll(NULL, 0, wait_ms) == 0) {
        code = ETIMEDOUT;
        goto fail;
      }
      if (errno != EINTR) {
        code = errno;
        goto fail;
      }
      continue;
    }

    struct pollfd fds[2];
    nfds_t nfds = 0;
    int in_at = -1;
    int out_at = -1;
    if (in_fd >= 0) {
      in_at = (int)nfds;
      fds[nfds++] = (struct pollfd){ .fd = in_fd, .events = POLLOUT };
    }
    if (out_fd >= 0) {
      out_at = (int)nfds;
      fds[nfds++] = (struct pollfd){ .fd = out_fd, .events = POLLIN };
    }
    int wait_ms = exec_poll_timeout(job, deadline);
    if (wait_ms == 0) {
      code = ETIMEDOUT;
      goto fail;
    }
    int ready = poll(fds, nfds, wait_ms);
    if (ready == 0) {
      code = ETIMEDOUT;
      goto fail;
    }
    if (ready < 0) {
      if (errno == EINTR) {
        continue;
      }
      code = errno;
      goto fail;
    }
    if (in_at >= 0 && fds[in_at].revents != 0) {
      if (fds[in_at].revents & POLLNVAL) {
        code = EBADF;
        goto fail;
      }
      if (fds[in_at].revents & POLLOUT) {
        sigset_t pending;
        int had_sigpipe;
        sigpending(&pending);
        had_sigpipe = sigismember(&pending, SIGPIPE) == 1;
        ssize_t made = write(in_fd, job->input + job->input_at,
          job->input_size - job->input_at);
        if (made > 0) {
          job->input_at += (size_t)made;
          if (job->input_at == job->input_size) {
            exec_close(&in_fd);
          }
        } else if (made < 0 && errno == EPIPE) {
          if (!had_sigpipe) {
            exec_consume_sigpipe();
          }
          exec_close(&in_fd);
        } else if (made < 0 && errno != EINTR && errno != EAGAIN) {
          code = errno;
          goto fail;
        }
      } else if (fds[in_at].revents & (POLLERR | POLLHUP)) {
        exec_close(&in_fd);
      }
    }
    if (out_at >= 0 && fds[out_at].revents != 0) {
      if (fds[out_at].revents & POLLNVAL) {
        code = EBADF;
        goto fail;
      }
      char chunk[EXEC_READ_CHUNK];
      ssize_t got = read(out_fd, chunk, sizeof chunk);
      if (got > 0) {
        code = exec_append(job, chunk, (size_t)got);
        if (code != 0) {
          goto fail;
        }
      } else if (got == 0) {
        exec_close(&out_fd);
      } else if (errno != EINTR && errno != EAGAIN) {
        code = errno;
        goto fail;
      }
    }
  }

  if (!child_done) {
    pid_t got;
    do {
      got = waitpid(pid, &status, 0);
    } while (got < 0 && errno == EINTR);
    if (got != pid) {
      code = errno == 0 ? ECHILD : errno;
      goto fail;
    }
    child_done = 1;
  }
  if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    code = WIFEXITED(status) ? WEXITSTATUS(status) : ETIMEDOUT;
    goto fail;
  }
  w->code = 0;
  if (sigpipe_blocked) {
    pthread_sigmask(SIG_SETMASK, &old_mask, NULL);
  }
  return;

fail:
  exec_cleanup_child(&in_fd, &out_fd, pid);
  exec_close(&in_pipe[0]);
  exec_close(&in_pipe[1]);
  exec_close(&out_pipe[0]);
  exec_close(&out_pipe[1]);
  w->code = code == 0 ? EIO : code;
  if (sigpipe_blocked) {
    pthread_sigmask(SIG_SETMASK, &old_mask, NULL);
  }
}
static Term exec_pack(Env e, IoWork* w) {
  ExecJob* job = (ExecJob*)w->data;
  Term result = w->code != 0 ? io_fail(e, w->code, NULL)
    : io_done(e, io_str(e, job->output, job->output_size));
  free(job->cmd);
  free(job->input);
  free(job->output);
  free(job);
  return result;
}

Term exec_run(Env e, Term* f, IoWork* w) {
  uint64_t cmd_size = 0;
  ExecJob* job = io_mem(calloc(1, sizeof *job));
  job->cmd = io_cstr(e, f[0], &cmd_size);
  job->input = io_cstr(e, f[1], &job->input_size);
  job->max_output = (u32)f[3];
  if (job->max_output == 0) {
    job->max_output = 1;
  }
  job->timeout_ms = (u32)f[2];
  job->output = io_mem(malloc(1));
  w->data = (char*)job;
  w->code = io_nul(job->cmd, cmd_size) ? EILSEQ : 0;
  return w->code != 0 ? exec_pack(e, w) : io_work(w, exec_call, exec_pack);
}

static void __attribute__((constructor)) exec_use(void) {
  io_eff(CID_EXEC_RUN, exec_run, 0);
}
