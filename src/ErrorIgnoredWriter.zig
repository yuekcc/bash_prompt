const std = @import("std");
const builtin = @import("builtin");
const File = std.fs.File;

_stdout: File,
_buffered_writer: std.io.BufferedWriter(4096, std.fs.File.DeprecatedWriter),

const Self = @This();

pub fn init() Self {
    var stdout = std.fs.File.stdout();
    const buffered_writer = std.io.bufferedWriter(stdout.deprecatedWriter());

    return .{
        ._stdout = stdout,
        ._buffered_writer = buffered_writer,
    };
}

pub fn close(self: *Self) void {
    self._buffered_writer.flush() catch unreachable;
    self._stdout.close();
}

pub fn print(self: *Self, comptime format: []const u8, args: anytype) void {
    self._buffered_writer.writer().print(format, args) catch unreachable;
}

test "ErrorIgnoreWriter" {
    if (builtin.target.os.tag != .windows) {
        var writer = init();
        defer writer.close();

        writer.print("hello", .{});
    }
}
