const std = @import("std");
const process = std.process;
const fmt = std.fmt;
const fs = std.fs;
const path = std.fs.path;

pub fn findRepoRoot(allocator: std.mem.Allocator, start: []const u8) ![]const u8 {
    const dot_git_path = try path.resolve(allocator, &[_][]const u8{ start, ".git" });

    // TODO: 优化判断方式
    if (fs.openDirAbsolute(dot_git_path, .{})) |_| {
        return start;
    } else |_| {
        const parent_dir = path.dirname(start);
        return findRepoRoot(allocator, parent_dir.?);
    }
}

pub fn gitInDir(allocator: std.mem.Allocator, dir: []const u8, argv: []const []const u8) !std.ChildProcess.ExecResult {
    var cmd_line = std.ArrayList([]const u8).init(allocator);
    defer cmd_line.deinit();

    try cmd_line.appendSlice(&[_][]const u8{ "git", "-C", dir });
    try cmd_line.appendSlice(argv);

    return std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = cmd_line.items,
    });
}

pub const Repo = struct {
    allocator: std.mem.Allocator,
    dir: []const u8,

    pub fn discover(allocator: std.mem.Allocator) !Repo {
        const cwd = try process.getCwdAlloc(allocator);
        const repo_dir = try findRepoRoot(allocator, cwd);

        return Repo{
            .allocator = allocator,
            .dir = repo_dir,
        };
    }

    fn git(self: *const Repo, argv: []const []const u8) !std.ChildProcess.ExecResult {
        return gitInDir(self.allocator, self.dir, argv);
    }

    pub fn getCurrentBranch(self: *const Repo) ![]const u8 {
        const output = try self.git(&[_][]const u8{ "rev-parse", "--abbrev-ref", "HEAD" });
        return std.mem.trim(u8, output.stdout, "\n");
    }

    pub fn getChanges(self: *const Repo) ![][]const u8 {
        const output = try self.git(&[_][]const u8{ "status", "--porcelain" });

        var result = std.ArrayList([]const u8).init(self.allocator);
        defer result.deinit();

        var splited = std.mem.split(u8, output.stdout, "\n");
        while (splited.next()) |entry| {
            try result.append(entry);
        }

        return result.items;
    }
};

test "find_dot_git" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const cwd = try process.getCwdAlloc(allocator);
    const repo_root = try findRepoRoot(allocator, cwd);
    std.debug.print("repo_root = {s}\n", .{repo_root});
}

test "exec_git_in_dir" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const cwd = try process.getCwdAlloc(allocator);
    const repo_root = try findRepoRoot(allocator, cwd);

    const cmd = try gitInDir(allocator, repo_root, &[_][]const u8{"version"});

    try std.testing.expectEqual(cmd.term, .{ .Exited = 0 });
    std.debug.print("stdout: {s}\n", .{cmd.stdout});
}

test "open_repo" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const repo = try Repo.discover(allocator);
    const branch = try repo.getCurrentBranch();
    std.debug.print("current branch: {s}\n", .{branch});

    const changes = try repo.getChanges();
    std.debug.print("current branch changes count: {d}\n", .{changes.len});
}
