const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");
const ControlSignal = types.ControlSignal;
const posix = std.posix;

const c = @cImport({
    @cInclude("unistd.h");
    @cInclude("fcntl.h");
    @cInclude("sys/ioctl.h");
    if (builtin.os.tag == .macos) {
        @cInclude("util.h");
    } else {
        @cInclude("pty.h");
    }
    @cInclude("signal.h");
});

pub const Transport = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        start: *const fn (ptr: *anyopaque) anyerror!void,
        stop: *const fn (ptr: *anyopaque) void,
        write: *const fn (ptr: *anyopaque, bytes: []const u8) anyerror!usize,
        read: *const fn (ptr: *anyopaque, buf: []u8) anyerror!usize,
        resize: *const fn (ptr: *anyopaque, cols: u16, rows: u16) anyerror!void,
        control: *const fn (ptr: *anyopaque, signal: ControlSignal) void,
    };

    pub fn start(self: Transport) anyerror!void {
        return self.vtable.start(self.ptr);
    }

    pub fn stop(self: Transport) void {
        self.vtable.stop(self.ptr);
    }

    pub fn write(self: Transport, bytes: []const u8) anyerror!usize {
        return self.vtable.write(self.ptr, bytes);
    }

    pub fn read(self: Transport, buf: []u8) anyerror!usize {
        return self.vtable.read(self.ptr, buf);
    }

    pub fn resize(self: Transport, cols: u16, rows: u16) anyerror!void {
        return self.vtable.resize(self.ptr, cols, rows);
    }

    pub fn control(self: Transport, signal: ControlSignal) void {
        self.vtable.control(self.ptr, signal);
    }
};

pub const MemTransport = struct {
    allocator: std.mem.Allocator,
    started: bool,
    rx: std.ArrayListUnmanaged(u8),
    tx: std.ArrayListUnmanaged(u8),
    last_cols: u16,
    last_rows: u16,
    last_signal: ?ControlSignal,

    pub fn init(allocator: std.mem.Allocator) MemTransport {
        return .{
            .allocator = allocator,
            .started = false,
            .rx = .empty,
            .tx = .empty,
            .last_cols = 0,
            .last_rows = 0,
            .last_signal = null,
        };
    }

    pub fn deinit(self: *MemTransport) void {
        self.rx.deinit(self.allocator);
        self.tx.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn transport(self: *MemTransport) Transport {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable: Transport.VTable = .{
        .start = startImpl,
        .stop = stopImpl,
        .write = writeImpl,
        .read = readImpl,
        .resize = resizeImpl,
        .control = controlImpl,
    };

    fn startImpl(ptr: *anyopaque) anyerror!void {
        const self: *MemTransport = @ptrCast(@alignCast(ptr));
        if (self.started) return error.AlreadyStarted;
        self.started = true;
    }

    fn stopImpl(ptr: *anyopaque) void {
        const self: *MemTransport = @ptrCast(@alignCast(ptr));
        self.started = false;
    }

    fn writeImpl(ptr: *anyopaque, bytes: []const u8) anyerror!usize {
        const self: *MemTransport = @ptrCast(@alignCast(ptr));
        if (!self.started) return error.NotStarted;
        try self.tx.appendSlice(self.allocator, bytes);
        return bytes.len;
    }

    fn readImpl(ptr: *anyopaque, buf: []u8) anyerror!usize {
        const self: *MemTransport = @ptrCast(@alignCast(ptr));
        if (!self.started) return error.NotStarted;
        const n = @min(buf.len, self.rx.items.len);
        if (n == 0) return 0;
        @memcpy(buf[0..n], self.rx.items[0..n]);
        const remaining = self.rx.items.len - n;
        std.mem.copyForwards(u8, self.rx.items[0..remaining], self.rx.items[n..]);
        self.rx.shrinkRetainingCapacity(remaining);
        return n;
    }

    fn resizeImpl(ptr: *anyopaque, cols: u16, rows: u16) anyerror!void {
        const self: *MemTransport = @ptrCast(@alignCast(ptr));
        if (!self.started) return error.NotStarted;
        self.last_cols = cols;
        self.last_rows = rows;
    }

    fn controlImpl(ptr: *anyopaque, signal: ControlSignal) void {
        const self: *MemTransport = @ptrCast(@alignCast(ptr));
        self.last_signal = signal;
    }
};

pub const FailTransport = struct {
    pub fn init() FailTransport {
        return .{};
    }

    pub fn deinit(self: *FailTransport) void {
        _ = self;
    }

    pub fn transport(self: *FailTransport) Transport {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable: Transport.VTable = .{
        .start = startImpl,
        .stop = stopImpl,
        .write = writeImpl,
        .read = readImpl,
        .resize = resizeImpl,
        .control = controlImpl,
    };

    fn startImpl(ptr: *anyopaque) anyerror!void {
        _ = ptr;
        return error.TransportFailed;
    }

    fn stopImpl(ptr: *anyopaque) void {
        _ = ptr;
    }

    fn writeImpl(ptr: *anyopaque, bytes: []const u8) anyerror!usize {
        _ = ptr;
        _ = bytes;
        return error.TransportFailed;
    }

    fn readImpl(ptr: *anyopaque, buf: []u8) anyerror!usize {
        _ = ptr;
        _ = buf;
        return error.TransportFailed;
    }

    fn resizeImpl(ptr: *anyopaque, cols: u16, rows: u16) anyerror!void {
        _ = ptr;
        _ = cols;
        _ = rows;
        return error.TransportFailed;
    }

    fn controlImpl(ptr: *anyopaque, signal: ControlSignal) void {
        _ = ptr;
        _ = signal;
    }
};

pub const UnixPtyTransport = struct {
    allocator: std.mem.Allocator,
    shell_path: [:0]u8,
    command: ?[:0]u8,
    started: bool,
    master_fd: ?posix.fd_t,
    child_pid: ?posix.pid_t,
    last_cols: u16,
    last_rows: u16,

    pub fn init(allocator: std.mem.Allocator, shell_path: []const u8, command: ?[]const u8) !UnixPtyTransport {
        if (builtin.os.tag != .linux and builtin.os.tag != .macos) return error.UnsupportedPlatform;
        const shell_z = try allocator.dupeZ(u8, shell_path);
        errdefer allocator.free(shell_z);
        const command_z = if (command) |cmd| try allocator.dupeZ(u8, cmd) else null;
        errdefer if (command_z) |z| allocator.free(z);
        return .{
            .allocator = allocator,
            .shell_path = shell_z,
            .command = command_z,
            .started = false,
            .master_fd = null,
            .child_pid = null,
            .last_cols = 0,
            .last_rows = 0,
        };
    }

    pub fn deinit(self: *UnixPtyTransport) void {
        self.stopInternal();
        self.allocator.free(self.shell_path);
        if (self.command) |cmd| self.allocator.free(cmd);
        self.* = undefined;
    }

    pub fn transport(self: *UnixPtyTransport) Transport {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn startInternal(self: *UnixPtyTransport) anyerror!void {
        if (self.started) return error.AlreadyStarted;

        var master_fd: c_int = -1;
        var slave_fd: c_int = -1;
        var winsize = c.struct_winsize{
            .ws_row = 24,
            .ws_col = 80,
            .ws_xpixel = 0,
            .ws_ypixel = 0,
        };
        if (c.openpty(&master_fd, &slave_fd, null, null, &winsize) != 0) {
            return error.OpenPtyFailed;
        }
        errdefer {
            if (master_fd >= 0) posix.close(@intCast(master_fd));
            if (slave_fd >= 0) posix.close(@intCast(slave_fd));
        }

        try setNonBlocking(@intCast(master_fd));

        const pid = try posix.fork();
        if (pid == 0) {
            childProcess(@intCast(slave_fd), self.shell_path, self.command) catch posix.exit(127);
            unreachable;
        }

        posix.close(@intCast(slave_fd));
        self.master_fd = @intCast(master_fd);
        self.child_pid = pid;
        self.started = true;
    }

    fn stopInternal(self: *UnixPtyTransport) void {
        if (!self.started) return;

        if (self.child_pid) |pid| {
            sendSignal(pid, @intCast(posix.SIG.TERM));
            reapChild(pid, 30);
        }
        if (self.master_fd) |fd| posix.close(fd);

        self.child_pid = null;
        self.master_fd = null;
        self.started = false;
    }

    const vtable: Transport.VTable = .{
        .start = startImpl,
        .stop = stopImpl,
        .write = writeImpl,
        .read = readImpl,
        .resize = resizeImpl,
        .control = controlImpl,
    };

    fn startImpl(ptr: *anyopaque) anyerror!void {
        const self: *UnixPtyTransport = @ptrCast(@alignCast(ptr));
        try self.startInternal();
    }

    fn stopImpl(ptr: *anyopaque) void {
        const self: *UnixPtyTransport = @ptrCast(@alignCast(ptr));
        self.stopInternal();
    }

    fn writeImpl(ptr: *anyopaque, bytes: []const u8) anyerror!usize {
        const self: *UnixPtyTransport = @ptrCast(@alignCast(ptr));
        if (!self.started or self.master_fd == null) return error.NotStarted;
        if (bytes.len == 0) return 0;
        const n = posix.write(self.master_fd.?, bytes) catch |err| switch (err) {
            error.WouldBlock => return 0,
            else => return err,
        };
        return n;
    }

    fn readImpl(ptr: *anyopaque, buf: []u8) anyerror!usize {
        const self: *UnixPtyTransport = @ptrCast(@alignCast(ptr));
        if (!self.started or self.master_fd == null) return error.NotStarted;
        if (buf.len == 0) return 0;
        const n = posix.read(self.master_fd.?, buf) catch |err| switch (err) {
            error.WouldBlock, error.InputOutput => return 0,
            else => return err,
        };
        return n;
    }

    fn resizeImpl(ptr: *anyopaque, cols: u16, rows: u16) anyerror!void {
        const self: *UnixPtyTransport = @ptrCast(@alignCast(ptr));
        if (!self.started or self.master_fd == null) return error.NotStarted;
        var winsize = c.struct_winsize{
            .ws_row = rows,
            .ws_col = cols,
            .ws_xpixel = 0,
            .ws_ypixel = 0,
        };
        if (c.ioctl(@intCast(self.master_fd.?), c.TIOCSWINSZ, &winsize) != 0) return error.ResizeFailed;
        self.last_cols = cols;
        self.last_rows = rows;
    }

    fn controlImpl(ptr: *anyopaque, signal: ControlSignal) void {
        const self: *UnixPtyTransport = @ptrCast(@alignCast(ptr));
        if (!self.started) return;
        if (self.child_pid) |pid| switch (signal) {
            .hangup => sendSignal(pid, @intCast(posix.SIG.HUP)),
            .interrupt => sendSignal(pid, @intCast(posix.SIG.INT)),
            .terminate => sendSignal(pid, @intCast(posix.SIG.TERM)),
            .resize_notify => sendSignal(pid, @intCast(posix.SIG.WINCH)),
        };
    }
};

fn setNonBlocking(fd: posix.fd_t) !void {
    const flags = posix.fcntl(fd, posix.F.GETFL, 0) catch return error.OpenPtyFailed;
    _ = posix.fcntl(fd, posix.F.SETFL, @as(u32, @intCast(flags)) | c.O_NONBLOCK) catch return error.OpenPtyFailed;
}

fn childProcess(slave_fd: posix.fd_t, shell_path: [:0]const u8, command: ?[:0]const u8) !void {
    _ = posix.setsid() catch {};
    _ = c.ioctl(@intCast(slave_fd), c.TIOCSCTTY, @as(c_ulong, 0));

    try posix.dup2(slave_fd, 0);
    try posix.dup2(slave_fd, 1);
    try posix.dup2(slave_fd, 2);
    if (slave_fd > 2) posix.close(slave_fd);

    if (command) |cmd| {
        const argv = [_:null]?[*:0]const u8{ shell_path.ptr, "-lc", cmd.ptr };
        const envp: [*:null]const ?[*:0]const u8 = @ptrCast(@constCast(std.c.environ));
        _ = posix.execvpeZ(shell_path.ptr, &argv, envp) catch {};
        posix.exit(127);
    }

    const argv = [_:null]?[*:0]const u8{shell_path.ptr};
    const envp: [*:null]const ?[*:0]const u8 = @ptrCast(@constCast(std.c.environ));
    _ = posix.execvpeZ(shell_path.ptr, &argv, envp) catch {};
    posix.exit(127);
}

fn sendSignal(pid: posix.pid_t, sig: u8) void {
    posix.kill(pid, sig) catch {};
}

fn reapChild(pid: posix.pid_t, timeout_ms: i64) void {
    const start_ms = std.time.milliTimestamp();
    while (true) {
        const res = posix.waitpid(pid, posix.W.NOHANG);
        if (res.pid != 0) return;
        if (std.time.milliTimestamp() - start_ms > timeout_ms) {
            sendSignal(pid, @intCast(posix.SIG.KILL));
            _ = posix.waitpid(pid, 0);
            return;
        }
        std.Thread.sleep(2 * std.time.ns_per_ms);
    }
}

test "start activates transport" {
    var mt = MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var t = mt.transport();
    try std.testing.expect(!mt.started);
    try t.start();
    try std.testing.expect(mt.started);
}

test "start twice returns AlreadyStarted" {
    var mt = MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var t = mt.transport();
    try t.start();
    try std.testing.expectError(error.AlreadyStarted, t.start());
}

test "stop deactivates transport" {
    var mt = MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var t = mt.transport();
    try t.start();
    t.stop();
    try std.testing.expect(!mt.started);
}

test "stop on idle transport is safe" {
    var mt = MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var t = mt.transport();
    t.stop();
    try std.testing.expect(!mt.started);
}

test "write appends to tx buffer" {
    var mt = MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var t = mt.transport();
    try t.start();
    const n = try t.write("hello");
    try std.testing.expectEqual(@as(usize, 5), n);
    try std.testing.expectEqualSlices(u8, "hello", mt.tx.items);
}

test "write before start returns NotStarted" {
    var mt = MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var t = mt.transport();
    try std.testing.expectError(error.NotStarted, t.write("hello"));
}

test "read drains rx buffer" {
    var mt = MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var t = mt.transport();
    try t.start();
    try mt.rx.appendSlice(std.testing.allocator, "world");
    var buf: [8]u8 = undefined;
    const n = try t.read(&buf);
    try std.testing.expectEqual(@as(usize, 5), n);
    try std.testing.expectEqualSlices(u8, "world", buf[0..n]);
    try std.testing.expectEqual(@as(usize, 0), mt.rx.items.len);
}

test "read before start returns NotStarted" {
    var mt = MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var t = mt.transport();
    var buf: [8]u8 = undefined;
    try std.testing.expectError(error.NotStarted, t.read(&buf));
}

test "read on empty rx returns 0" {
    var mt = MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var t = mt.transport();
    try t.start();
    var buf: [8]u8 = undefined;
    const n = try t.read(&buf);
    try std.testing.expectEqual(@as(usize, 0), n);
}

test "read partial drains only up to buf size" {
    var mt = MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var t = mt.transport();
    try t.start();
    try mt.rx.appendSlice(std.testing.allocator, "abcdef");
    var buf: [3]u8 = undefined;
    const n = try t.read(&buf);
    try std.testing.expectEqual(@as(usize, 3), n);
    try std.testing.expectEqualSlices(u8, "abc", buf[0..n]);
    try std.testing.expectEqualSlices(u8, "def", mt.rx.items);
}

test "resize records last dimensions" {
    var mt = MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var t = mt.transport();
    try t.start();
    try t.resize(132, 50);
    try std.testing.expectEqual(@as(u16, 132), mt.last_cols);
    try std.testing.expectEqual(@as(u16, 50), mt.last_rows);
}

test "resize before start returns NotStarted" {
    var mt = MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var t = mt.transport();
    try std.testing.expectError(error.NotStarted, t.resize(132, 50));
}

test "control records last signal" {
    var mt = MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var t = mt.transport();
    try t.start();
    t.control(.interrupt);
    try std.testing.expectEqual(ControlSignal.interrupt, mt.last_signal.?);
}

test "session holds transport reference" {
    const session_mod = @import("session.zig");
    var mt = MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    const t = mt.transport();
    var s = try session_mod.Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80,
        .rows = 24,
        .pending_capacity = 4096,
        .transport = t,
    });
    defer s.deinit();
    try std.testing.expect(s.transport != null);
}

fn readUntilContains(t: Transport, allocator: std.mem.Allocator, needle: []const u8, timeout_ms: u64) !bool {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);
    var buf: [512]u8 = undefined;

    const start_ms: u64 = @intCast(std.time.milliTimestamp());
    while (true) {
        const n = try t.read(&buf);
        if (n > 0) try out.appendSlice(allocator, buf[0..n]);
        if (std.mem.indexOf(u8, out.items, needle) != null) return true;

        const now_ms: u64 = @intCast(std.time.milliTimestamp());
        if (now_ms - start_ms > timeout_ms) return false;
        std.Thread.sleep(5 * std.time.ns_per_ms);
    }
}

test "unix pty transport: headless bash command stdout is readable" {
    if (builtin.os.tag != .linux and builtin.os.tag != .macos) return error.SkipZigTest;

    var pty = try UnixPtyTransport.init(std.testing.allocator, "/bin/bash", "printf 'M2_PTY_STDOUT_OK\\n'; exit\n");
    defer pty.deinit();
    var t = pty.transport();

    try t.start();
    const found = try readUntilContains(t, std.testing.allocator, "M2_PTY_STDOUT_OK", 3000);
    try std.testing.expect(found);
    t.stop();
    try std.testing.expect(!pty.started);
}

test "unix pty transport: resize and stop are deterministic" {
    if (builtin.os.tag != .linux and builtin.os.tag != .macos) return error.SkipZigTest;

    var pty = try UnixPtyTransport.init(std.testing.allocator, "/bin/bash", "while true; do sleep 1; done");
    defer pty.deinit();
    var t = pty.transport();

    try t.start();
    try t.resize(132, 50);
    try std.testing.expectEqual(@as(u16, 132), pty.last_cols);
    try std.testing.expectEqual(@as(u16, 50), pty.last_rows);

    t.control(.terminate);
    t.stop();
    try std.testing.expect(!pty.started);
    try std.testing.expect(pty.master_fd == null);
    try std.testing.expect(pty.child_pid == null);
}
