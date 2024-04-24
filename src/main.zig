const std = @import("std");
const builtin = @import("builtin");
const process = std.process;
const knownFolders = @import("known-folders");

const styles = @import("styles.zig").styles;
const Repo = @import("git.zig").Repo;
const ErrorIgnoreWriter = @import("ErrorIgnoredWriter.zig");

fn getPathDelimiter() []const u8 {
    if (builtin.os.tag == .windows) {
        return "\\";
    } else {
        return "/";
    }
}

fn printInstallScript(writer: *ErrorIgnoreWriter, exe_name: []const u8) !void {
    const script = "\nPROMPT_COMMAND=\"{s}\"; export PROMPT_COMMAND; PS1=\"\\$ \";";
    writer.print(script, .{exe_name});
}

fn printPrompt(allocator: std.mem.Allocator, writer: *ErrorIgnoreWriter, enable_short_paths: bool) !void {
    const pwd = try process.getCwdAlloc(allocator);
    defer allocator.free(pwd);

    const home_dir = try knownFolders.getPath(allocator, .home);
    defer allocator.free(home_dir.?);

    const updated_pwd = try std.mem.replaceOwned(u8, allocator, pwd, home_dir.?, "~");
    defer allocator.free(updated_pwd);

    // _ = std.mem.replace(u8, updated_pwd, "\\", "/", updated_pwd);
    var iter = std.mem.splitSequence(u8, updated_pwd, getPathDelimiter());
    var path_buf = std.ArrayList([]const u8).init(allocator);

    while (iter.next()) |p| {
        const str = try allocator.dupe(u8, p);
        try path_buf.append(str);
    }

    if (enable_short_paths) {
        for (0..path_buf.items.len) |i| {
            if (i == 0 or i == path_buf.items.len - 1) {
                continue;
            }

            var utf8_str = try std.unicode.Utf8View.init(path_buf.items[i]);
            var utf8_str_iter = utf8_str.iterator();
            path_buf.items[i] = utf8_str_iter.nextCodepointSlice().?;
        }
    }

    const formated = try path_buf.toOwnedSlice();
    defer allocator.free(formated);
    const pwd_display = try std.mem.join(allocator, "/", formated);
    defer allocator.free(pwd_display);

    writer.print("\r\n", .{});
    writer.print(styles.fg_blue ++ "{s}" ++ styles.sgr_reset, .{pwd_display});
    defer writer.print("\r\n", .{});

    var repo = Repo.discover(allocator) catch return;
    defer repo.deinit();

    const branch_name = repo.getCurrentBranch() catch return;
    defer allocator.free(branch_name);
    if (branch_name.len > 0) {
        writer.print(" @ ", .{});
        writer.print(styles.fg_yellow ++ "{s}" ++ styles.sgr_reset, .{branch_name});

        const changes = repo.getChanges() catch return;
        defer allocator.free(changes);
        if (changes.len > 0) {
            writer.print(styles.fg_red ++ "*" ++ styles.sgr_reset, .{});

            const change_count = repo.countChanges() catch "";
            defer allocator.free(change_count);

            writer.print(" {s}", .{change_count});
        }
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var writer = ErrorIgnoreWriter.init();
    defer writer.close();

    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    const exe_name = args_iter.next().?;
    var enable_short_paths = false;
    while (args_iter.next()) |flag| {
        if (std.mem.eql(u8, flag[0..], "init")) {
            try printInstallScript(&writer, exe_name);
            return;
        } else if (std.mem.eql(u8, flag, "short")) {
            enable_short_paths = true;
        }
    }

    try printPrompt(allocator, &writer, enable_short_paths);
}

test "find home dir" {
    const home_dir = try knownFolders.getPath(std.testing.allocator, .home);
    defer std.testing.allocator.free(home_dir.?);

    std.debug.print("home dir: {s}\n", .{home_dir.?});
}
