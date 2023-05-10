const std = @import("std");
const process = std.process;
const knownFolders = @import("known-folders");

const styles = @import("styles.zig").styles;
const Repo = @import("git.zig").Repo;

fn printInstallScript(writer: anytype, exe_name: []const u8) !void {
    comptime var script = "\nPROMPT_COMMAND=\"{s}\"; export PROMPT_COMMAND; PS1=\"\\$ \";";
    try writer.print(script, .{exe_name});
}

fn printPrompt(allocator: std.mem.Allocator, writer: anytype) !void {
    var pwd = try process.getCwdAlloc(allocator);
    defer allocator.free(pwd);

    var home_dir = try knownFolders.getPath(allocator, .home);
    defer allocator.free(home_dir.?);

    var updated_pwd = try std.mem.replaceOwned(u8, allocator, pwd, home_dir.?, "~");
    defer allocator.free(updated_pwd);

    _ = std.mem.replace(u8, updated_pwd, "\\", "/", updated_pwd);

    try writer.print("\r\n", .{});
    try writer.print(styles.fg_blue ++ "{s}" ++ styles.sgr_reset, .{updated_pwd});
    defer writer.print("\r\n", .{}) catch @panic("unable to write data to stdout");

    var repo = Repo.discover(allocator) catch return;
    defer repo.deinit();

    var branch_name = repo.getCurrentBranch() catch return;
    defer allocator.free(branch_name);
    if (branch_name.len > 0) {
        try writer.print(" @ ", .{});
        try writer.print(styles.fg_yellow ++ "{s}" ++ styles.sgr_reset, .{branch_name});

        var changes = repo.getChanges() catch return;
        defer allocator.free(changes);
        if (changes.len > 0) {
            try writer.print(styles.fg_red ++ "*" ++ styles.sgr_reset, .{});

            const change_count = repo.countChanges() catch "";
            defer allocator.free(change_count);

            try writer.print(" {s}", .{change_count});
        }
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var stdout = std.io.getStdOut();
    defer stdout.close();

    var buffered_stdout = std.io.bufferedWriter(stdout.writer());
    var writer = buffered_stdout.writer();
    defer buffered_stdout.flush() catch @panic("unable to write data to stdout");

    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    var exe_name = args_iter.next().?;
    var init_flag = args_iter.next() orelse "";
    if (std.mem.eql(u8, init_flag[0..], "init")) {
        try printInstallScript(writer, exe_name);
        return;
    }

    try printPrompt(allocator, writer);
}

test "find home dir" {
    const home_dir = try knownFolders.getPath(std.testing.allocator, .home);
    defer std.testing.allocator.free(home_dir.?);

    std.debug.print("home dir: {s}\n", .{home_dir.?});
}
