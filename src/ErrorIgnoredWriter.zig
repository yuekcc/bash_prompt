const std = @import("std");
const builtin = @import("builtin");
const File = std.fs.File;
const Writer = std.io.Writer;

var _file: File = undefined;
var _stdout_writer: File.Writer = undefined;
var _buffer: [1024]u8 = undefined;

_stdout: *Writer,

const Self = @This();

pub fn init() Self {
    _file = std.fs.File.stdout();
    _stdout_writer = _file.writer(&_buffer);

    return .{
        ._stdout = &_stdout_writer.interface,
    };
}

pub fn close(self: *Self) void {
    self._stdout.flush() catch unreachable;
    _file.close();
}

pub fn print(self: *Self, comptime format: []const u8, args: anytype) void {
    self._stdout.print(format, args) catch unreachable;
}

test "ErrorIgnoreWriter" {
    var w = init();

    w.print("hello ErrorIgnoreWriter", .{});
    w.close();
}

test "BufferWriter" {
    var test_buffer: [4096]u8 = undefined;
    var file = std.fs.File.stdout();
    var w = file.writer(&test_buffer);
    var stdout = &w.interface;
    try stdout.print("hello BufferWriter", .{});
    try stdout.flush();
    file.close();
}
