const std = @import("std");
const types = @import("types.zig");
const ControlSignal = types.ControlSignal;

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
        try self.tx.appendSlice(self.allocator, bytes);
        return bytes.len;
    }

    fn readImpl(ptr: *anyopaque, buf: []u8) anyerror!usize {
        const self: *MemTransport = @ptrCast(@alignCast(ptr));
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
        self.last_cols = cols;
        self.last_rows = rows;
    }

    fn controlImpl(ptr: *anyopaque, signal: ControlSignal) void {
        const self: *MemTransport = @ptrCast(@alignCast(ptr));
        self.last_signal = signal;
    }
};

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
