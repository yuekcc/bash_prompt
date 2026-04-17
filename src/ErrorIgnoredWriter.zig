const std = @import("std");

const Writer = std.Io.Writer;

_stdout: *Writer,

const Self = @This();

pub fn init(w: *Writer) Self {
    return .{
        ._stdout = w,
    };
}

pub fn close(self: *Self) void {
    self._stdout.flush() catch unreachable;
}

pub fn print(self: *Self, comptime format: []const u8, args: anytype) void {
    self._stdout.print(format, args) catch unreachable;
}

test "ErrorIgnoreWriter init" {
    var buf: [256]u8 = undefined;
    var w = std.Io.Writer.fixed(&buf);
    var writer = init(&w);

    writer.print("test: {}", .{42});
    try std.testing.expectEqualStrings("test: 42", buf[0..8]);
}

test "ErrorIgnoreWriter close" {
    var buf: [256]u8 = undefined;
    var w = std.Io.Writer.fixed(&buf);
    var writer = init(&w);

    writer.print("hello", .{});
    writer.close();

    try std.testing.expectEqualStrings("hello", buf[0..5]);
}

test "BufferWriter" {
    var test_buffer: [256]u8 = undefined;
    var w = std.Io.Writer.fixed(&test_buffer);
    try w.print("hello BufferWriter", .{});
    try w.flush();
    const written = std.mem.trim(u8, w.buffer[0..w.end], "\x00");
    try std.testing.expectEqualStrings("hello BufferWriter", written);
}
