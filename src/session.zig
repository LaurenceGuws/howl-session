const std = @import("std");

pub const ControlSignal = enum {
    hangup,
    interrupt,
    terminate,
    resize_notify,
};

pub const SessionStatus = enum {
    idle,
    active,
    stopped,
};

pub const Config = struct {
    allocator: std.mem.Allocator,
    cols: u16,
    rows: u16,
};

pub const Session = struct {
    allocator: std.mem.Allocator,
    cols: u16,
    rows: u16,

    pub fn init(config: Config) error{InvalidConfig}!Session {
        if (config.cols == 0 or config.rows == 0) return error.InvalidConfig;
        return .{
            .allocator = config.allocator,
            .cols = config.cols,
            .rows = config.rows,
        };
    }

    pub fn deinit(self: *Session) void {
        self.* = undefined;
    }

    pub fn feed(self: *Session, bytes: []const u8) void {
        _ = self;
        _ = bytes;
    }

    pub fn apply(self: *Session) usize {
        _ = self;
        return 0;
    }

    pub fn reset(self: *Session) void {
        _ = self;
    }

    pub fn resize(self: *Session, cols: u16, rows: u16) error{InvalidDimensions}!void {
        if (cols == 0 or rows == 0) return error.InvalidDimensions;
        self.cols = cols;
        self.rows = rows;
    }

    pub fn control(self: *Session, signal: ControlSignal) void {
        _ = self;
        _ = signal;
    }
};

test "init rejects zero cols" {
    const result = Session.init(.{ .allocator = std.testing.allocator, .cols = 0, .rows = 24 });
    try std.testing.expectError(error.InvalidConfig, result);
}

test "init rejects zero rows" {
    const result = Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 0 });
    try std.testing.expectError(error.InvalidConfig, result);
}

test "init succeeds with valid config" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24 });
    defer s.deinit();
    try std.testing.expectEqual(@as(u16, 80), s.cols);
    try std.testing.expectEqual(@as(u16, 24), s.rows);
}

test "feed and apply are callable" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24 });
    defer s.deinit();
    s.feed("hello");
    try std.testing.expectEqual(@as(usize, 0), s.apply());
}

test "reset is callable" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24 });
    defer s.deinit();
    s.reset();
}

test "resize rejects zero dimensions" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24 });
    defer s.deinit();
    try std.testing.expectError(error.InvalidDimensions, s.resize(0, 24));
    try std.testing.expectError(error.InvalidDimensions, s.resize(80, 0));
}

test "resize updates dimensions" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24 });
    defer s.deinit();
    try s.resize(132, 50);
    try std.testing.expectEqual(@as(u16, 132), s.cols);
    try std.testing.expectEqual(@as(u16, 50), s.rows);
}

test "control is callable" {
    var s = try Session.init(.{ .allocator = std.testing.allocator, .cols = 80, .rows = 24 });
    defer s.deinit();
    s.control(.hangup);
}
