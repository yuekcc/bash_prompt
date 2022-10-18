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
        {
            // 设置一个代码块，用于释放 git_dir

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
pub fn gitInDir(arena: *std.heap.ArenaAllocator, dir: []const u8, argv: []const []const u8) !std.ChildProcess.ExecResult {
    var allocator = arena.allocator();

    var cmd_line = std.ArrayList([]const u8).init(allocator);
    defer cmd_line.deinit();

    try cmd_line.appendSlice(&[_][]const u8{ "git", "-C", dir });
    try cmd_line.appendSlice(argv);

    return std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = cmd_line.toOwnedSlice(),
    });
}

pub const Repo = struct {
    arena_allocator: std.heap.ArenaAllocator,
    dir: []const u8,

    const Self = @This();

    pub fn discover(allocator: std.mem.Allocator) !Self {
        var arena_allocator = std.heap.ArenaAllocator.init(allocator);
        var allocator_ = arena_allocator.allocator();
        errdefer arena_allocator.deinit();

        var cwd = try process.getCwdAlloc(allocator_);
        var repo_dir = try findRepoRoot(allocator_, cwd);

        return Self{
            .arena_allocator = arena_allocator,
            .dir = repo_dir,
        };
    }

    pub fn deinit(self: *Self) void {
        self.arena_allocator.deinit();
    }

    fn getAllocator(self: *Self) std.mem.Allocator {
        return self.arena_allocator.allocator();
    }

    fn git(self: *Self, argv: []const []const u8) !std.ChildProcess.ExecResult {
        return gitInDir(&self.arena_allocator, self.dir, argv);
    }

    pub fn getCurrentBranch(self: *Self) ![]const u8 {
        var output = try self.git(&[_][]const u8{ "rev-parse", "--abbrev-ref", "HEAD" });
        return std.mem.trim(u8, output.stdout, "\n");
    }

    pub fn getChanges(self: *Self) ![][]const u8 {
        var output = try self.git(&[_][]const u8{ "status", "--porcelain" });

        var result = std.ArrayList([]const u8).init(self.getAllocator());
        defer result.deinit();

        var splited = std.mem.split(u8, output.stdout, "\n");
        while (splited.next()) |entry| {
            var clean = std.mem.trim(u8, entry, "\n");
            if (clean.len > 0) {
                try result.append(clean);
            }
        }

        return result.toOwnedSlice();
    }
};

test "find_dot_git" {
    var allocator = std.testing.allocator;

    var cwd = try process.getCwdAlloc(allocator);
    defer allocator.free(cwd);

    var repo_root = try findRepoRoot(allocator, cwd);
    defer allocator.free(repo_root);

    std.debug.print("repo_root = {s}\n", .{repo_root});
}

test "exec_git_in_dir" {
    var allocator = std.testing.allocator;

    var cwd = try process.getCwdAlloc(allocator);
    defer allocator.free(cwd);

    var repo_root = try findRepoRoot(allocator, cwd);
    defer allocator.free(repo_root);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var cmd = try gitInDir(&arena, repo_root, &[_][]const u8{"version"});

    try std.testing.expectEqual(cmd.term, .{ .Exited = 0 });
    std.debug.print("stdout: {s}\n", .{cmd.stdout});
}

test "test_repo_obj" {
    var allocator = std.testing.allocator;
    var repo = try Repo.discover(allocator);
    defer repo.deinit();

    var branch = try repo.getCurrentBranch();
    std.debug.print("current branch: {s}\n", .{branch});

    const changes = try repo.getChanges();
    std.debug.print("current branch changes count: {d}\n", .{changes.len});
}
