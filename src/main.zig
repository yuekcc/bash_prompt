const std = @import("std");
const builtin = @import("builtin");
const process = std.process;
const knownFolders = @import("known-folders");
const String = @import("string").String;

const styles = @import("styles.zig").styles;
const Repo = @import("git.zig").Repo;
const ErrorIgnoreWriter = @import("ErrorIgnoredWriter.zig");

const CliFlag = struct {
    exe_name: []const u8,
    show_init: bool,
    use_short_path: bool,
};

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

fn printPrompt(p_allocator: std.mem.Allocator, writer: *ErrorIgnoreWriter, cli_flag: *CliFlag) !void {
    var arena = std.heap.ArenaAllocator.init(p_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const cwd = try process.getCwdAlloc(allocator);
    const home_dir = try knownFolders.getPath(allocator, .home);
    const updated_pwd = try std.mem.replaceOwned(u8, allocator, cwd, home_dir.?, "~");

    var iter = std.mem.splitSequence(u8, updated_pwd, getPathDelimiter());
    var path_buf = std.ArrayList([]const u8).init(allocator);

    while (iter.next()) |p| {
        const str = try allocator.dupe(u8, p);
        try path_buf.append(str);
    }

    if (cli_flag.use_short_path) {
        for (0..path_buf.items.len) |i| {
            if (i == 0 or i == path_buf.items.len - 1) {
                continue;
            }

            const str = try String.init_with_contents(allocator, path_buf.items[i]);
            path_buf.items[i] = try allocator.dupe(u8, str.charAt(0).?);
        }
    }

    const formated = try path_buf.toOwnedSlice();
    const pwd_display = try std.mem.join(allocator, "/", formated);

    writer.print("\r\n", .{});
    writer.print(styles.fg_blue ++ "{s}" ++ styles.sgr_reset, .{pwd_display});
    defer writer.print("\r\n", .{});

    var repo = Repo.discover(allocator) catch return;
    defer repo.deinit();

    const branch_name = repo.getCurrentBranch() catch return;
    if (branch_name.len > 0) {
        writer.print(" @ ", .{});
        writer.print(styles.fg_yellow ++ "{s}" ++ styles.sgr_reset, .{branch_name});

        const changes = repo.getChanges() catch return;
        if (changes.len > 0) {
            writer.print(styles.fg_red ++ "*" ++ styles.sgr_reset, .{});

            const change_count = repo.countChanges() catch "";

            writer.print(" {s}", .{change_count});
        }
    }
}

fn parseCliFlag(allocator: std.mem.Allocator) !*CliFlag {
    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    const exe_name = args_iter.next().?;

    var out = try allocator.create(CliFlag);
    out.exe_name = try allocator.dupe(u8, exe_name);
    out.show_init = false;
    out.use_short_path = false;

    while (args_iter.next()) |flag| {
        if (std.mem.eql(u8, flag, "init")) {
            out.show_init = true;
        } else if (std.mem.eql(u8, flag, "short")) {
            out.use_short_path = true;
        }
    }

    return out;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var writer = ErrorIgnoreWriter.init();
    defer writer.close();

    const cli_flag = try parseCliFlag(allocator);
    defer allocator.destroy(cli_flag);

    if (cli_flag.show_init) {
        try printInstallScript(&writer, cli_flag.exe_name);
        return;
    }

    try printPrompt(allocator, &writer, cli_flag);
}

test "find home dir" {
    const home_dir = try knownFolders.getPath(std.testing.allocator, .home);
    defer std.testing.allocator.free(home_dir.?);

    std.debug.print("home dir: {s}\n", .{home_dir.?});
}
