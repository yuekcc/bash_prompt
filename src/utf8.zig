/// Copy from https://github.com/JakubSzark/zig-string
const std = @import("std");

/// Returns the UTF-8 character's size
inline fn getUTF8Size(char: u8) u3 {
    return std.unicode.utf8ByteSequenceLength(char) catch {
        return 1;
    };
}

/// Returns the real index of a unicode string literal
fn getIndex(unicode: []const u8, index: usize, real: bool) ?usize {
    var i: usize = 0;
    var j: usize = 0;
    while (i < unicode.len) {
        if (real) {
            if (j == index) return i;
        } else {
            if (i == index) return j;
        }
        i += getUTF8Size(unicode[i]);
        j += 1;
    }

    return null;
}

/// Returns a character at the specified index
pub fn charAt(str: ?[]const u8, index: usize) ?[]const u8 {
    if (str) |buffer| {
        if (getIndex(buffer, index, true)) |i| {
            const size = getUTF8Size(buffer[i]);
            return buffer[i..(i + size)];
        }
    }
    return null;
}
