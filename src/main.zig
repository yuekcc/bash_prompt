const std = @import("std");
const process = std.process;

// Control Sequence Introducer
const CSI = "\x1B[";

// ANSI Escape Code
pub const ESC = "\x1B";

const Color4 = enum(u7) {
    black = 30,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37,
    default = 39,
    bright_black = 90,
    bright_red = 91,
    bright_green = 92,
    bright_yellow = 93,
    bright_blue = 94,
    bright_magenta = 95,
    bright_cyan = 96,
    bright_white = 97,
};

fn bgColor4(writer: anytype, mode: Color4) !void {
    try writer.print(CSI ++ "{d}m", .{@enumToInt(mode) + 10});
}

fn fgColor4(writer: anytype, mode: Color4) !void {
    try writer.print(CSI ++ "{d}m", .{@enumToInt(mode)});
}

fn resetAll(writer: anytype) !void {
    try writer.writeAll(ESC ++ "c");
}

fn resetSGR(writer: anytype) !void {
    try writer.writeAll(CSI ++ "0m");
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const pwd = try process.getCwdAlloc(allocator);
    
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("\n", .{});
    try fgColor4(stdout, .blue);
    try stdout.print("{s}", .{pwd});
    try resetSGR(stdout);
    try stdout.print("\n", .{});

    try bw.flush();
}

test "fgColor4" {
    const stdout = std.io.getStdOut().writer();
    try fgColor4(stdout, .blue);
    try stdout.print("xxxx", .{});
    try resetSGR(stdout);
}
