pub fn expectEqual(expected: anytype, actual: anytype) !void {
    const std = @import("std");
    try std.testing.expectEqual(expected.cols, actual.cols);
    try std.testing.expectEqual(expected.rows, actual.rows);
    try std.testing.expectEqual(expected.status, actual.status);
    try std.testing.expectEqual(expected.resize_count, actual.resize_count);
    try std.testing.expectEqual(expected.last_control_signal, actual.last_control_signal);
}
