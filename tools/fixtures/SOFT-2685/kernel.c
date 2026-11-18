#define _GNU_SOURCE
#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdatomic.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

typedef struct {
    int kind, fd, pid, exited, signaled;
    pthread_t thread;
    pthread_mutex_t mutex;
    pthread_cond_t condition;
} Handle;
static int leaked[2] = {-1, -1};
static _Atomic int writing_large_packet;
int mp_writing_large_packet(void) { return atomic_load(&writing_large_packet); }
int mp_pause(Handle *h) { return kill(h->pid, SIGSTOP) == 0 && waitpid(h->pid, 0, WUNTRACED) == h->pid; }
static Handle *handle(int kind, int fd, int pid) {
    Handle *h = calloc(1, sizeof(*h));
    h->kind = kind; h->fd = fd; h->pid = pid;
    pthread_mutex_init(&h->mutex, 0);
    pthread_cond_init(&h->condition, 0);
    return h;
}
static void interrupted(int signal) { (void)signal; }
void mp_release_leaks(void) {
    for (int i = 0; i < 2; i++) if (leaked[i] >= 0) { close(leaked[i]); leaked[i] = -1; }
}
int mp_spawn(const char *broker, void **process, void **input, void **output, int retain) {
    int in[2], out[2];
    atomic_store(&writing_large_packet, 0);
    if (pipe(in) || pipe(out)) return 0;
    pid_t pid = fork();
    if (pid == 0) {
        dup2(in[0], 0); dup2(out[1], 1);
        close(in[0]); close(in[1]); close(out[0]); close(out[1]);
        execlp("python3", "python3", "-u", broker, (char *)0);
        _exit(127);
    }
    if (pid < 0) return 0;
    if (retain) { leaked[0] = dup(in[0]); leaked[1] = dup(out[1]); }
    close(in[0]); close(out[1]);
    *process = handle(2, -1, pid); *input = handle(1, in[1], 0); *output = handle(1, out[0], 0);
    struct sigaction sa = {0}; sa.sa_handler = interrupted; sigaction(SIGUSR1, &sa, 0);
    signal(SIGPIPE, SIG_IGN);
    return 1;
}
int ReadFile(Handle *h, void *buffer, uint32_t size, uint32_t *count, void *overlapped) {
    (void)overlapped;
    ssize_t n = read(h->fd, buffer, size); *count = n > 0 ? n : 0; return n >= 0;
}
int WriteFile(Handle *h, const void *buffer, uint32_t size, uint32_t *count, void *overlapped) {
    (void)overlapped;
    if (size > 65536) atomic_store(&writing_large_packet, 1);
    ssize_t n = write(h->fd, buffer, size); *count = n > 0 ? n : 0; return n >= 0;
}
void *CreateEventW(void *security, int manual, int initial, void *name) {
    (void)security; (void)name;
    Handle *h = handle(3, manual, 0); h->signaled = initial; return h;
}
int SetEvent(Handle *h) {
    pthread_mutex_lock(&h->mutex); h->signaled = 1; pthread_cond_broadcast(&h->condition); pthread_mutex_unlock(&h->mutex); return 1;
}
uint32_t WaitForSingleObject(Handle *h, uint32_t timeout) {
    if (h->kind == 2) {
        do {
            pthread_mutex_lock(&h->mutex);
            if (!h->exited) h->exited = waitpid(h->pid, 0, WNOHANG) == h->pid;
            int exited = h->exited;
            pthread_mutex_unlock(&h->mutex);
            if (exited) return 0;
            if (!timeout) return 258;
            usleep(1000);
        } while (timeout == UINT32_MAX || --timeout);
        return 258;
    }
    pthread_mutex_lock(&h->mutex);
    struct timespec deadline; clock_gettime(CLOCK_REALTIME, &deadline);
    deadline.tv_sec += timeout / 1000; deadline.tv_nsec += (timeout % 1000) * 1000000L;
    if (deadline.tv_nsec >= 1000000000L) { deadline.tv_sec++; deadline.tv_nsec -= 1000000000L; }
    while (!h->signaled) {
        int result = timeout == UINT32_MAX ? pthread_cond_wait(&h->condition, &h->mutex) : pthread_cond_timedwait(&h->condition, &h->mutex, &deadline);
        if (result == ETIMEDOUT) { pthread_mutex_unlock(&h->mutex); return 258; }
    }
    if (!h->fd) h->signaled = 0;
    pthread_mutex_unlock(&h->mutex); return 0;
}
uint32_t WaitForMultipleObjects(uint32_t count, Handle **handles, int all, uint32_t timeout) {
    (void)all;
    do {
        for (uint32_t i = 0; i < count; i++) if (WaitForSingleObject(handles[i], 0) == 0) return i;
        if (!timeout) return 258;
        usleep(1000);
    } while (timeout == UINT32_MAX || --timeout);
    return 258;
}
int TerminateProcess(Handle *h, uint32_t code) { (void)code; return kill(h->pid, SIGKILL) == 0; }
int CloseHandle(Handle *h) {
    if (h->kind == 1) close(h->fd);
    pthread_mutex_destroy(&h->mutex); pthread_cond_destroy(&h->condition); free(h); return 1;
}
void *GetCurrentProcess(void) { return 0; }
void *GetCurrentThread(void) { return (void *)pthread_self(); }
void mp_set_thread(Handle *h, uintptr_t thread) { h->thread = (pthread_t)thread; }
int DuplicateHandle(void *source, void *thread, void *target, void **copy, uint32_t access, int inherit, uint32_t options) {
    (void)source; (void)target; (void)access; (void)inherit; (void)options;
    Handle *h = handle(4, 0, 0); h->thread = (pthread_t)thread; *copy = h; return 1;
}
int CancelSynchronousIo(Handle *thread) { return pthread_kill(thread->thread, SIGUSR1) == 0; }
uint64_t GetTickCount64(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1000ULL + t.tv_nsec / 1000000; }
void Sleep(uint32_t ms) { usleep(ms * 1000); }
int PostMessageW(void *window, uint32_t message, uintptr_t user, intptr_t value) {
    (void)window; (void)message; (void)user; (void)value; return 1;
}
