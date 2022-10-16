const std = @import("std");
const process = std.process;

const styles = @import("styles.zig").styles;
const Repo = @import("git.zig").Repo;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const pwd = try process.getCwdAlloc(allocator);

    const stdout_writer = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_writer);
    const stdout = bw.writer();

    try stdout.print("\n", .{});

    try stdout.print(styles.fg_blue ++ "{s}" ++ styles.sgr_reset, .{pwd});

    if (Repo.discover(allocator)) |repo| {
        const branch_name = try repo.getCurrentBranch();
        const changes = try repo.getChanges();

        try stdout.print(" @ ", .{});
        try stdout.print(styles.fg_yellow ++ "{s}" ++ styles.sgr_reset, .{branch_name});
        if (changes.len > 0) {
            try stdout.print(styles.fg_red ++ "*" ++ styles.sgr_reset, .{});
        }
    } else |_| {
        unreachable;
    }

    try stdout.print("\n", .{});

    try bw.flush();
}
