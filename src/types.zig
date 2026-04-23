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
