const std = @import("std");
const File = std.fs.File;

_stdout: File,
_buffered_writer: std.io.BufferedWriter(4096, File.Writer),

const Self = @This();

pub fn init() Self {
    var stdout = std.io.getStdOut();
    var buffered_writer = std.io.bufferedWriter(stdout.writer());

    return .{
        ._stdout = stdout,
        ._buffered_writer = buffered_writer,
    };
}

pub fn close(self: *Self) void {
    self._buffered_writer.flush() catch @panic("unable to write data to STDOUT");
    self._stdout.close();
}

pub fn print(self: *Self, comptime format: []const u8, args: anytype) void {
    self._buffered_writer.writer().print(format, args) catch @panic("unable to write data to STDOUT");
}

test "ErrorIgnoreWriter" {
    var writer = init();
    defer writer.close();

    writer.print("hello", .{});
}
