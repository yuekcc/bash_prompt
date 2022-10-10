const std = @import("std");
const process = std.process;
const fmt = std.fmt;

// https://chrisyeh96.github.io/2020/03/28/terminal-colors.html
const CSI = "\x1B[";
const ESC = "\x1B";

const DefaultColor = enum(u8) {
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

fn Styles() type {
    comptime var fg_red = fmt.comptimePrint(CSI ++ "{d}m", .{@enumToInt(DefaultColor.red)});
    comptime var fg_blue = fmt.comptimePrint(CSI ++ "{d}m", .{@enumToInt(DefaultColor.blue)});
    comptime var fg_yellow = fmt.comptimePrint(CSI ++ "{d}m", .{@enumToInt(DefaultColor.yellow)});
    comptime var sgr_reset = CSI ++ "0m";

    return struct {
        // 重置样式
        sgr_reset: []const u8 = sgr_reset,

        fg_red: []const u8 = fg_red,
        fg_blue: []const u8 = fg_blue,
        fg_yellow: []const u8 = fg_yellow,
    };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const pwd = try process.getCwdAlloc(allocator);

    const stdout_writer = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_writer);
    const stdout = bw.writer();

    const styles = Styles(){};
    comptime var pwd_layout = "\n" ++ styles.fg_blue ++ "{s}" ++ styles.sgr_reset ++ "\n";
    try stdout.print(pwd_layout, .{pwd});

    try bw.flush();
}

test {
    const styles = Styles(){};

    const stdout = std.io.getStdOut().writer();
    comptime var pwd_layout = "\n" ++ styles.fg_red ++ "{s}" ++ styles.sgr_reset ++ "\n";
    try stdout.print(pwd_layout, .{"hello, world"});
}
