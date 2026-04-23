const std = @import("std");
const types = @import("types.zig");
const transport_mod = @import("transport.zig");

pub const ControlSignal = types.ControlSignal;
pub const SessionStatus = types.SessionStatus;
pub const Transport = transport_mod.Transport;

pub const Config = struct {
    allocator: std.mem.Allocator,
    cols: u16,
    rows: u16,
    pending_capacity: usize,
    transport: ?Transport = null,
};

pub const Session = struct {
    allocator: std.mem.Allocator,
    cols: u16,
    rows: u16,
    status: SessionStatus,
    pending: std.ArrayListUnmanaged(u8),
    pending_capacity: usize,
    transport: ?Transport,
    resize_count: u32,
    last_control_signal: ?ControlSignal,

    pub fn init(config: Config) error{InvalidConfig}!Session {
        if (config.cols == 0 or config.rows == 0) return error.InvalidConfig;
        if (config.pending_capacity == 0) return error.InvalidConfig;
        return .{
            .allocator = config.allocator,
            .cols = config.cols,
            .rows = config.rows,
            .status = .idle,
            .pending = .empty,
            .pending_capacity = config.pending_capacity,
            .transport = config.transport,
            .resize_count = 0,
            .last_control_signal = null,
        };
    }

    pub fn deinit(self: *Session) void {
        self.pending.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn start(self: *Session) anyerror!void {
        if (self.status == .active) return error.AlreadyStarted;
        if (self.transport) |t| try t.start();
        self.status = .active;
    }

    pub fn stop(self: *Session) void {
        if (self.status == .active) {
            if (self.transport) |t| t.stop();
        }
        self.status = .stopped;
    }

    pub fn feed(self: *Session, bytes: []const u8) error{ OutOfMemory, QueueFull }!void {
        const projected_len = std.math.add(usize, self.pending.items.len, bytes.len) catch return error.QueueFull;
        if (projected_len > self.pending_capacity) return error.QueueFull;
        try self.pending.appendSlice(self.allocator, bytes);
    }

    pub fn apply(self: *Session) usize {
        const n = self.pending.items.len;
        self.pending.clearRetainingCapacity();
        return n;
    }

    pub fn reset(self: *Session) void {
        self.pending.clearRetainingCapacity();
    }

    pub fn resize(self: *Session, cols: u16, rows: u16) anyerror!void {
        if (cols == 0 or rows == 0) return error.InvalidDimensions;
        self.cols = cols;
        self.rows = rows;
        self.resize_count +%= 1;
        if (self.transport) |t| try t.resize(cols, rows);
    }

    pub fn control(self: *Session, signal: ControlSignal) void {
        self.last_control_signal = signal;
        if (self.transport) |t| t.control(signal);
    }
};

test "init rejects zero cols" {
    const result = Session.init(.{ .allocator = std.testing.allocator, .cols = 0, .rows = 24, .pending_capacity = 4096 });
    try std.testing.expectError(error.InvalidConfig, result);
}

test "init rejects zero rows" {
    const result = Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 0, .pending_capacity = 4096 });
    try std.testing.expectError(error.InvalidConfig, result);
}

test "init succeeds with valid config" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    try std.testing.expectEqual(@as(u16, 80), s.cols);
    try std.testing.expectEqual(@as(u16, 24), s.rows);
}

test "feed and apply are callable" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    try s.feed("hello");
    try std.testing.expectEqual(@as(usize, 5), s.apply());
}

test "reset is callable" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    s.reset();
}

test "resize rejects zero dimensions" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    try std.testing.expectError(error.InvalidDimensions, s.resize(0, 24));
    try std.testing.expectError(error.InvalidDimensions, s.resize(80, 0));
}

test "resize updates dimensions" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    try s.resize(132, 50);
    try std.testing.expectEqual(@as(u16, 132), s.cols);
    try std.testing.expectEqual(@as(u16, 50), s.rows);
}

test "control is callable" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    s.control(.hangup);
}

test "feed accumulates, apply drains in full" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    try s.feed("abc");
    try s.feed("de");
    try std.testing.expectEqual(@as(usize, 5), s.apply());
    try std.testing.expectEqual(@as(usize, 0), s.apply());
}

test "apply returns 0 on empty queue" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 0), s.apply());
}

test "reset clears queue, apply returns 0" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    try s.feed("queued");
    s.reset();
    try std.testing.expectEqual(@as(usize, 0), s.apply());
}

test "reset does not alter dimensions" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    try s.feed("data");
    s.reset();
    try std.testing.expectEqual(@as(u16, 80), s.cols);
    try std.testing.expectEqual(@as(u16, 24), s.rows);
}

test "resize idempotent on same dimensions" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    try s.resize(80, 24);
    try std.testing.expectEqual(@as(u16, 80), s.cols);
    try std.testing.expectEqual(@as(u16, 24), s.rows);
}

test "control accepts all signal variants" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    s.control(.hangup);
    s.control(.interrupt);
    s.control(.terminate);
    s.control(.resize_notify);
}

test "status is idle after init" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    try std.testing.expectEqual(SessionStatus.idle, s.status);
}

test "init rejects zero pending_capacity" {
    const result = Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 0 });
    try std.testing.expectError(error.InvalidConfig, result);
}

test "feed overflow returns QueueFull" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 8 });
    defer s.deinit();
    try std.testing.expectError(error.QueueFull, s.feed("123456789"));
}


test "feed overflow is atomic: no partial write" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4 });
    defer s.deinit();
    try s.feed("ab");
    try std.testing.expectError(error.QueueFull, s.feed("cde"));
    try std.testing.expectEqual(@as(usize, 2), s.apply());
}

test "apply after overflow drains only accepted bytes" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 5 });
    defer s.deinit();
    try s.feed("hello");
    try std.testing.expectError(error.QueueFull, s.feed("!"));
    try std.testing.expectEqual(@as(usize, 5), s.apply());
}

test "reset clears full queue, feed succeeds again" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4 });
    defer s.deinit();
    try s.feed("abcd");
    try std.testing.expectError(error.QueueFull, s.feed("e"));
    s.reset();
    try s.feed("xy");
    try std.testing.expectEqual(@as(usize, 2), s.apply());
}

test "feed up to exact capacity succeeds" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 6 });
    defer s.deinit();
    try s.feed("abc");
    try s.feed("def");
    try std.testing.expectEqual(@as(usize, 6), s.apply());
}

test "start with null transport is no-op and succeeds" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    try s.start();
    try std.testing.expectEqual(SessionStatus.active, s.status);
}

test "stop with null transport is no-op and sets stopped" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    s.stop();
    try std.testing.expectEqual(SessionStatus.stopped, s.status);
}

test "start with MemTransport delegates to transport" {
    var mt = transport_mod.MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var s = try Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80,
        .rows = 24,
        .pending_capacity = 4096,
        .transport = mt.transport(),
    });
    defer s.deinit();
    try s.start();
    try std.testing.expect(mt.started);
    try std.testing.expectEqual(SessionStatus.active, s.status);
}

test "stop with MemTransport delegates to transport" {
    var mt = transport_mod.MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var s = try Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80,
        .rows = 24,
        .pending_capacity = 4096,
        .transport = mt.transport(),
    });
    defer s.deinit();
    try s.start();
    s.stop();
    try std.testing.expect(!mt.started);
    try std.testing.expectEqual(SessionStatus.stopped, s.status);
}

test "resize with transport delegates dims and notifies" {
    var mt = transport_mod.MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var s = try Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80,
        .rows = 24,
        .pending_capacity = 4096,
        .transport = mt.transport(),
    });
    defer s.deinit();
    try s.start();
    try s.resize(132, 50);
    try std.testing.expectEqual(@as(u16, 132), s.cols);
    try std.testing.expectEqual(@as(u16, 50), s.rows);
    try std.testing.expectEqual(@as(u16, 132), mt.last_cols);
    try std.testing.expectEqual(@as(u16, 50), mt.last_rows);
}

test "resize without transport still updates session dimensions" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    try s.resize(120, 40);
    try std.testing.expectEqual(@as(u16, 120), s.cols);
    try std.testing.expectEqual(@as(u16, 40), s.rows);
}

test "control with transport routes signal" {
    var mt = transport_mod.MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var s = try Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80,
        .rows = 24,
        .pending_capacity = 4096,
        .transport = mt.transport(),
    });
    defer s.deinit();
    s.control(.terminate);
    try std.testing.expectEqual(ControlSignal.terminate, mt.last_signal.?);
}

test "control without transport is no-op" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    s.control(.hangup);
}

test "feed/apply/reset unaffected by transport attachment" {
    var mt = transport_mod.MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var s = try Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80,
        .rows = 24,
        .pending_capacity = 8,
        .transport = mt.transport(),
    });
    defer s.deinit();
    try s.start();
    try s.feed("abc");
    try s.feed("de");
    try std.testing.expectEqual(@as(usize, 5), s.apply());
    try s.feed("xyz");
    s.reset();
    try std.testing.expectEqual(@as(usize, 0), s.apply());
    try std.testing.expectError(error.QueueFull, s.feed("123456789"));
}

test "start from idle transitions to active" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    try std.testing.expectEqual(SessionStatus.idle, s.status);
    try s.start();
    try std.testing.expectEqual(SessionStatus.active, s.status);
}

test "start from active returns AlreadyStarted, no status change" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    try s.start();
    try std.testing.expectError(error.AlreadyStarted, s.start());
    try std.testing.expectEqual(SessionStatus.active, s.status);
}

test "start from active does not double-start transport" {
    var mt = transport_mod.MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var s = try Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80, .rows = 24, .pending_capacity = 4096,
        .transport = mt.transport(),
    });
    defer s.deinit();
    try s.start();
    try std.testing.expectError(error.AlreadyStarted, s.start());
    try std.testing.expect(mt.started);
}

test "stop from active transitions to stopped and calls transport" {
    var mt = transport_mod.MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var s = try Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80, .rows = 24, .pending_capacity = 4096,
        .transport = mt.transport(),
    });
    defer s.deinit();
    try s.start();
    s.stop();
    try std.testing.expectEqual(SessionStatus.stopped, s.status);
    try std.testing.expect(!mt.started);
}

test "stop from idle transitions to stopped without calling transport" {
    var mt = transport_mod.MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var s = try Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80, .rows = 24, .pending_capacity = 4096,
        .transport = mt.transport(),
    });
    defer s.deinit();
    s.stop();
    try std.testing.expectEqual(SessionStatus.stopped, s.status);
    try std.testing.expect(!mt.started);
}

test "stop from stopped is idempotent, transport not called again" {
    var mt = transport_mod.MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var s = try Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80, .rows = 24, .pending_capacity = 4096,
        .transport = mt.transport(),
    });
    defer s.deinit();
    try s.start();
    s.stop();
    s.stop();
    try std.testing.expectEqual(SessionStatus.stopped, s.status);
    try std.testing.expect(!mt.started);
}

test "start from stopped restarts transport" {
    var mt = transport_mod.MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var s = try Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80, .rows = 24, .pending_capacity = 4096,
        .transport = mt.transport(),
    });
    defer s.deinit();
    try s.start();
    s.stop();
    try s.start();
    try std.testing.expectEqual(SessionStatus.active, s.status);
    try std.testing.expect(mt.started);
}

test "start from stopped without transport transitions to active" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24, .pending_capacity = 4096 });
    defer s.deinit();
    s.stop();
    try s.start();
    try std.testing.expectEqual(SessionStatus.active, s.status);
}

test "full lifecycle cycle: idle-active-stopped-active" {
    var mt = transport_mod.MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var s = try Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80, .rows = 24, .pending_capacity = 4096,
        .transport = mt.transport(),
    });
    defer s.deinit();
    try std.testing.expectEqual(SessionStatus.idle, s.status);
    try s.start();
    try std.testing.expectEqual(SessionStatus.active, s.status);
    try std.testing.expect(mt.started);
    s.stop();
    try std.testing.expectEqual(SessionStatus.stopped, s.status);
    try std.testing.expect(!mt.started);
    try s.start();
    try std.testing.expectEqual(SessionStatus.active, s.status);
    try std.testing.expect(mt.started);
}

test "start failure from idle leaves status idle" {
    var ft = transport_mod.FailTransport.init();
    defer ft.deinit();
    var s = try Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80, .rows = 24, .pending_capacity = 4096,
        .transport = ft.transport(),
    });
    defer s.deinit();
    try std.testing.expectError(error.TransportFailed, s.start());
    try std.testing.expectEqual(SessionStatus.idle, s.status);
}

test "start failure from stopped leaves status stopped" {
    var mt = transport_mod.MemTransport.init(std.testing.allocator);
    defer mt.deinit();
    var ft = transport_mod.FailTransport.init();
    defer ft.deinit();
    var s = try Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80, .rows = 24, .pending_capacity = 4096,
        .transport = mt.transport(),
    });
    defer s.deinit();
    try s.start();
    s.stop();
    s.transport = ft.transport();
    try std.testing.expectError(error.TransportFailed, s.start());
    try std.testing.expectEqual(SessionStatus.stopped, s.status);
}

test "start failure is repeatable and deterministic" {
    var ft = transport_mod.FailTransport.init();
    defer ft.deinit();
    var s = try Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80, .rows = 24, .pending_capacity = 4096,
        .transport = ft.transport(),
    });
    defer s.deinit();
    try std.testing.expectError(error.TransportFailed, s.start());
    try std.testing.expectError(error.TransportFailed, s.start());
    try std.testing.expectEqual(SessionStatus.idle, s.status);
}

test "resize failure retains updated dims" {
    var ft = transport_mod.FailTransport.init();
    defer ft.deinit();
    var s = try Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80, .rows = 24, .pending_capacity = 4096,
        .transport = ft.transport(),
    });
    defer s.deinit();
    try std.testing.expectError(error.TransportFailed, s.resize(132, 50));
    try std.testing.expectEqual(@as(u16, 132), s.cols);
    try std.testing.expectEqual(@as(u16, 50), s.rows);
}

test "resize failure is repeatable and deterministic" {
    var ft = transport_mod.FailTransport.init();
    defer ft.deinit();
    var s = try Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80, .rows = 24, .pending_capacity = 4096,
        .transport = ft.transport(),
    });
    defer s.deinit();
    try std.testing.expectError(error.TransportFailed, s.resize(100, 40));
    try std.testing.expectError(error.TransportFailed, s.resize(120, 48));
    try std.testing.expectEqual(@as(u16, 120), s.cols);
    try std.testing.expectEqual(@as(u16, 48), s.rows);
}

test "feed/apply/reset unaffected after start failure" {
    var ft = transport_mod.FailTransport.init();
    defer ft.deinit();
    var s = try Session.init(.{
        .allocator = std.testing.allocator,
        .cols = 80, .rows = 24, .pending_capacity = 4096,
        .transport = ft.transport(),
    });
    defer s.deinit();
    try std.testing.expectError(error.TransportFailed, s.start());
    try s.feed("hello");
    try std.testing.expectEqual(@as(usize, 5), s.apply());
    try s.feed("world");
    s.reset();
    try std.testing.expectEqual(@as(usize, 0), s.apply());
}
