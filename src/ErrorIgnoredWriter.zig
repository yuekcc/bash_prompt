const std = @import("std");
const builtin = @import("builtin");
const File = std.fs.File;
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

test "ErrorIgnoreWriter" {
    var buf: [1024]u8 = undefined;
    var file = File.stdout();
    defer file.close();
    var writer = file.writer(&buf);

    var w = init(&writer.interface);

    w.print("hello ErrorIgnoreWriter", .{});
    w.close();
}

test "BufferWriter" {
    var test_buffer: [4096]u8 = undefined;
    var file = std.fs.File.stdout();
    var file_writer = file.writer(&test_buffer);
    var stdout = &file_writer.interface;
    try stdout.print("hello BufferWriter", .{});
    try stdout.flush();
    file.close();
}
