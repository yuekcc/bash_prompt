const std = @import("std");
const process = std.process;

const styles = @import("styles.zig").styles;
const Repo = @import("git.zig").Repo;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    var allocator = gpa.allocator();

    var pwd = try process.getCwdAlloc(allocator);
    defer allocator.free(pwd);

    var stdout_writer = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_writer);
    var stdout = bw.writer();

    try stdout.print("\n", .{});

    try stdout.print(styles.fg_blue ++ "{s}" ++ styles.sgr_reset, .{pwd});

    var repo = Repo.discover(allocator);
    if (repo) |*repo_| {
        defer repo_.deinit();

        var branch_name = try repo_.getCurrentBranch();
        var changes = try repo_.getChanges();

        try stdout.print(" @ ", .{});
        try stdout.print(styles.fg_yellow ++ "{s}" ++ styles.sgr_reset, .{branch_name});
        if (changes.len > 0) {
            try stdout.print(styles.fg_red ++ "*" ++ styles.sgr_reset, .{});
        }
    } else |_| {
        // do nothing on error
    }

    try stdout.print("\n", .{});
    try bw.flush();
}
