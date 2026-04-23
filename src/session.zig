const std = @import("std");

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

    pub fn control(self: *Session, signal: u8) void {
        _ = self;
        _ = signal;
    }
};
