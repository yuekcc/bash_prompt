const std = @import("std");
const process = std.process;
const fmt = std.fmt;
const fs = std.fs;
const path = std.fs.path;

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

pub const styles = struct {
    pub const sgr_reset = CSI ++ "0m";

    pub const fg_red = fmt.comptimePrint(CSI ++ "{d}m", .{@enumToInt(DefaultColor.red)});
    pub const fg_blue = fmt.comptimePrint(CSI ++ "{d}m", .{@enumToInt(DefaultColor.blue)});
    pub const fg_yellow = fmt.comptimePrint(CSI ++ "{d}m", .{@enumToInt(DefaultColor.yellow)});
};

test "colors" {
    const pwd_layout = "\n" ++ styles.fg_red ++ "{s}" ++ styles.sgr_reset ++ "\n";
    std.debug.print(pwd_layout, .{"hello, world"});
}
