const std = @import("std");

pub const session = @import("session.zig");
pub const Session = session.Session;
pub const SessionConfig = session.Config;
pub const ControlSignal = session.ControlSignal;
pub const SessionStatus = session.SessionStatus;
pub const transport = @import("transport.zig");
pub const Transport = transport.Transport;
pub const MemTransport = transport.MemTransport;
pub const FailTransport = transport.FailTransport;

test "host API: all symbols exported" {
    _ = Session;
    _ = SessionConfig;
    _ = ControlSignal;
    _ = SessionStatus;
    _ = Transport;
    _ = MemTransport;
    _ = FailTransport;
}

test "host API: SessionConfig required fields present" {
    comptime {
        std.debug.assert(@hasField(SessionConfig, "allocator"));
        std.debug.assert(@hasField(SessionConfig, "cols"));
        std.debug.assert(@hasField(SessionConfig, "rows"));
        std.debug.assert(@hasField(SessionConfig, "pending_capacity"));
        std.debug.assert(@hasField(SessionConfig, "transport"));
    }
}

test "host API: Session required methods present" {
    comptime {
        _ = Session.init;
        _ = Session.deinit;
        _ = Session.start;
        _ = Session.stop;
        _ = Session.feed;
        _ = Session.apply;
        _ = Session.reset;
        _ = Session.resize;
        _ = Session.control;
    }
}

test "host API: Session observability fields present" {
    comptime {
        std.debug.assert(@hasField(Session, "status"));
        std.debug.assert(@hasField(Session, "cols"));
        std.debug.assert(@hasField(Session, "rows"));
        std.debug.assert(@hasField(Session, "resize_count"));
        std.debug.assert(@hasField(Session, "last_control_signal"));
    }
}

test "host API: ControlSignal required variants present" {
    _ = ControlSignal.hangup;
    _ = ControlSignal.interrupt;
    _ = ControlSignal.terminate;
    _ = ControlSignal.resize_notify;
}

test "host API: SessionStatus required variants present" {
    _ = SessionStatus.idle;
    _ = SessionStatus.active;
    _ = SessionStatus.stopped;
}

test "host API: Transport vtable methods present" {
    comptime {
        _ = Transport.start;
        _ = Transport.stop;
        _ = Transport.write;
        _ = Transport.read;
        _ = Transport.resize;
        _ = Transport.control;
    }
}
