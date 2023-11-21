const std = @import("std");
const process = std.process;
const fs = std.fs;
const path = std.fs.path;

const RepoError = error{
    NotFound,
};

pub fn findRepoRoot(allocator: std.mem.Allocator, start: []const u8) ![]const u8 {
    var current = start;
    var dir: fs.Dir = undefined;

    while (true) {
        // 设置一个代码块，用于释放 git_dir
        {
            var git_dir = try path.resolve(allocator, &[_][]const u8{ current, ".git" });
            defer allocator.free(git_dir);

            dir = fs.openDirAbsolute(git_dir, .{}) catch {
                var parent_dir = path.dirname(current);

                // 如果 current 是根目录，parent_dir = null
                if (parent_dir == null) {
                    return RepoError.NotFound;
                }

                // 设置为父目录，继续查找 .git 目录
                current = parent_dir.?;
                continue;
            };
        }
        dir.close();
        break;
    }

    return allocator.dupe(u8, current);
}

// 用 arena 分配器解决内部内存释放问题
pub fn gitInDir(allocator: std.mem.Allocator, dir: []const u8, argv: []const []const u8) !std.ChildProcess.RunResult {
    var cmd_line = std.ArrayList([]const u8).init(allocator);
    defer cmd_line.deinit();

    try cmd_line.appendSlice(&[_][]const u8{ "git", "-C", dir });
    try cmd_line.appendSlice(argv);

    const combined = try cmd_line.toOwnedSlice();
    defer allocator.free(combined);

    return std.ChildProcess.run(.{
        .allocator = allocator,
        .argv = combined,
    });
}

pub const Repo = struct {
    allocator: std.mem.Allocator,
    dir: []const u8,

    const Self = @This();

    pub fn discover(allocator: std.mem.Allocator) !Self {
        var cwd = try process.getCwdAlloc(allocator);
        defer allocator.free(cwd);

        var repo_dir = try findRepoRoot(allocator, cwd);
        defer allocator.free(repo_dir);

        return Self{
            .allocator = allocator,
            .dir = try allocator.dupe(u8, repo_dir),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.dir);
    }

    fn git(self: *Self, argv: []const []const u8) ![]const u8 {
        const cmd_result = try gitInDir(self.allocator, self.dir, argv);
        const cmd_output = if (cmd_result.term.Exited == 0) cmd_result.stdout else "";
        defer self.allocator.free(cmd_result.stdout);
        defer self.allocator.free(cmd_result.stderr);

        const result = std.mem.trim(u8, cmd_output, "\n");
        return self.allocator.dupe(u8, result);
    }

    pub fn getCurrentBranch(self: *Self) ![]const u8 {
        return self.git(&[_][]const u8{ "rev-parse", "--abbrev-ref", "HEAD" });
    }

    pub fn getChanges(self: *Self) ![][]const u8 {
        var output = try self.git(&[_][]const u8{ "status", "--porcelain" });
        defer self.allocator.free(output);

        var result = std.ArrayList([]const u8).init(self.allocator);
        defer result.deinit();

        var splitted = std.mem.split(u8, output, "\n");
        while (splitted.next()) |entry| {
            var clean = std.mem.trim(u8, entry, "\n");
            if (clean.len > 0) {
                try result.append(clean);
            }
        }

        return result.toOwnedSlice();
    }

    pub fn countChanges(self: *Self) ![]u8 {
        var output = try self.git(&[_][]const u8{ "diff", "--numstat", "HEAD" });
        defer self.allocator.free(output);

        var result = std.ArrayList([]const u8).init(self.allocator);
        defer result.deinit();

        var splits = std.mem.split(u8, output, "\n");
        var insertions: u64 = 0;
        var deletions: u64 = 0;
        while (splits.next()) |entry| {
            // std.debug.print("entry = {s}\n", .{entry});

            var iter = std.mem.tokenize(u8, entry, "\t");
            var inserted = iter.next().?;
            var deleted = iter.next().?;

            // std.debug.print("inserted, deleted = {s} {s}\n", .{ inserted, deleted });

            var inserted_num = try std.fmt.parseInt(u8, inserted, 10);
            var deleted_num = try std.fmt.parseInt(u8, deleted, 10);

            insertions = insertions + inserted_num;
            deletions = deletions + deleted_num;
        }

        return std.fmt.allocPrint(self.allocator, "+{d}, -{d}", .{ insertions, deletions });
    }
};

test "find .git dir" {
    var allocator = std.testing.allocator;

    var cwd = try process.getCwdAlloc(allocator);
    defer allocator.free(cwd);

    var repo_root = try findRepoRoot(allocator, cwd);
    defer allocator.free(repo_root);

    std.debug.print("repo_root = {s}\n", .{repo_root});
}

test "execute git cmd in that dir" {
    var allocator = std.testing.allocator;

    var cwd = try process.getCwdAlloc(allocator);
    defer allocator.free(cwd);

    var repo_root = try findRepoRoot(allocator, cwd);
    defer allocator.free(repo_root);

    var cmd = try gitInDir(allocator, repo_root, &[_][]const u8{"version"});
    defer allocator.free(cmd.stdout);
    defer allocator.free(cmd.stderr);

    try std.testing.expectEqual(cmd.term, .{ .Exited = 0 });
    std.debug.print("stdout: {s}\n", .{cmd.stdout});
}

test "call repo object methods" {
    var allocator = std.testing.allocator;
    var repo = try Repo.discover(allocator);
    defer repo.deinit();

    var branch = try repo.getCurrentBranch();
    defer allocator.free(branch);
    std.debug.print("current branch: {s}\n", .{branch});

    const changes = try repo.getChanges();
    defer allocator.free(changes);
    std.debug.print("current branch changes count: {d}\n", .{changes.len});

    const change_count = try repo.countChanges();
    defer allocator.free(change_count);
    std.debug.print("count changes: {s}\n", .{change_count});
}
