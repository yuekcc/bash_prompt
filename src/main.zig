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

    try writer.print("\n", .{});
    try writer.print(styles.fg_blue ++ "{s}" ++ styles.sgr_reset, .{updated_pwd});

    var repo = Repo.discover(allocator);
    if (repo) |*repo_| {
        defer repo_.deinit();

        var branch_name = repo_.getCurrentBranch() catch "";
        if (branch_name.len > 0) {
            try writer.print(" @ ", .{});
            try writer.print(styles.fg_yellow ++ "{s}" ++ styles.sgr_reset, .{branch_name});

            var changes = repo_.getChanges() catch ([_][]const u8{""})[0..];
            if (changes.len > 0) {
                try writer.print(styles.fg_red ++ "*" ++ styles.sgr_reset, .{});
            }
        }
    } else |_| {
        // do nothing on error
    }

    try writer.print("\r\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    var allocator = gpa.allocator();

    var stdout = std.io.getStdOut().writer();
    var buffered_stdout = std.io.bufferedWriter(stdout);
    var writer = buffered_stdout.writer();

    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    _ = args_iter.skip();
    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg[0..], "init")) {
            try printInstallScript(writer, "bash_prompt");
            try buffered_stdout.flush();
            return;
        }
    }

    try printPrompt(allocator, writer);
    try buffered_stdout.flush();
}

test "find home dir" {
    const home_dir = try knownFolders.getPath(std.testing.allocator, .home);
    defer std.testing.allocator.free(home_dir.?);

    std.debug.print("home dir: {s}\n", .{home_dir.?});
}
