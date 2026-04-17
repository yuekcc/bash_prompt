const std = @import("std");
const path = std.fs.path;

const RepoError = error{
    NotFound,
};

/// 从给定路径向上查找 .git 目录，返回仓库根路径。
/// 返回 owned 字符串，调用者负责释放。
pub fn findRepoRoot(allocator: std.mem.Allocator, io: std.Io, start: []const u8) ![]const u8 {
    var current = start;
    var dir: std.Io.Dir = undefined;

    while (true) {
        const git_dir = try path.resolve(allocator, &[_][]const u8{ current, ".git" });
        defer allocator.free(git_dir);

        dir = std.Io.Dir.openDirAbsolute(io, git_dir, .{}) catch {
            const parent_dir = path.dirname(current);

            if (parent_dir == null) {
                return RepoError.NotFound;
            }

            current = parent_dir.?;
            continue;
        };
        dir.close(io);
        break;
    }

    return allocator.dupe(u8, current);
}

/// 在指定目录下执行 git 命令。
/// 返回 owned 字符串，调用者负责释放。
pub fn gitInDir(allocator: std.mem.Allocator, io: std.Io, dir: []const u8, argv: []const []const u8) !std.process.RunResult {
    var cmd_line = std.array_list.Managed([]const u8).init(allocator);
    defer cmd_line.deinit();

    try cmd_line.appendSlice(&[_][]const u8{ "git", "-C", dir });
    try cmd_line.appendSlice(argv);

    const combined = try cmd_line.toOwnedSlice();
    defer allocator.free(combined);

    return std.process.run(allocator, io, .{
        .argv = combined,
        .create_no_window = true,
    });
}

pub const DiffState = struct {
    files_changed: u32,
    insertions: u32,
    deletions: u32,
};

fn parseDiffShortState(input: []const u8) !DiffState {
    var result = DiffState{
        .files_changed = 0,
        .insertions = 0,
        .deletions = 0,
    };

    var lines = std.mem.splitAny(u8, input, "\n");
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "file") != null) {
            var num: u32 = 0;
            var it = std.mem.tokenizeSequence(u8, line, " ");
            while (it.next()) |token| {
                if (std.fmt.parseInt(u32, token, 10)) |num_| {
                    num = num_;
                } else |_| {}

                if (std.mem.indexOf(u8, token, "file") != null) {
                    result.files_changed = num;
                    continue;
                }

                if (std.mem.indexOf(u8, token, "insertions") != null) {
                    result.insertions = num;
                    continue;
                }
                if (std.mem.indexOf(u8, token, "deletions") != null) {
                    result.deletions = num;
                    continue;
                }
            }
            break;
        }
    }

    return result;
}

test "parse git diff --shortstat HEAD output" {
    const input =
        \\warning: in the working copy of 'src/styles.zig', CRLF will be replaced by LF the next time Git touches it
        \\2 files changed, 2 insertions(+), 5 deletions(-)
    ;

    const stat = try parseDiffShortState(input);
    try std.testing.expectEqual(@as(u32, 2), stat.files_changed);
    try std.testing.expectEqual(@as(u32, 2), stat.insertions);
    try std.testing.expectEqual(@as(u32, 5), stat.deletions);
}

pub const Repo = struct {
    allocator: std.mem.Allocator,
    dir: []const u8,
    io: std.Io,

    const Self = @This();

    pub fn discover(allocator: std.mem.Allocator, io: std.Io, cwd: []const u8) !Self {
        const repo_dir = try findRepoRoot(allocator, io, cwd);
        errdefer allocator.free(repo_dir);

        return Self{
            .allocator = allocator,
            .dir = repo_dir,
            .io = io,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.dir);
    }

    fn git(self: *Self, argv: []const []const u8) ![]const u8 {
        const cmd_result = try gitInDir(self.allocator, self.io, self.dir, argv);
        defer self.allocator.free(cmd_result.stdout);
        defer self.allocator.free(cmd_result.stderr);

        if (cmd_result.term.exited != 0) {
            return "";
        }

        const result = std.mem.trim(u8, cmd_result.stdout, "\n");
        return self.allocator.dupe(u8, result);
    }

    /// 返回 owned 字符串，调用者负责释放。
    /// 如果没有当前分支（空仓库），返回长度为 0 的字符串，无需释放。
    pub fn getCurrentBranch(self: *Self) ![]const u8 {
        return self.git(&[_][]const u8{ "rev-parse", "--abbrev-ref", "HEAD" });
    }

    pub fn diffState(self: *Self) !DiffState {
        const output = try self.git(&[_][]const u8{ "diff", "--shortstat", "HEAD" });
        defer self.allocator.free(output);

        return parseDiffShortState(output);
    }
};

test "find .git dir" {
    const testing_io = std.testing.io;

    const cwd = try std.process.currentPathAlloc(testing_io, std.testing.allocator);
    defer std.testing.allocator.free(cwd);

    const repo_root = try findRepoRoot(std.testing.allocator, testing_io, cwd);
    defer std.testing.allocator.free(repo_root);

    std.debug.print("repo_root = {s}\n", .{repo_root});
}

test "execute git cmd in that dir" {
    const testing_io = std.testing.io;

    const cwd = try std.process.currentPathAlloc(testing_io, std.testing.allocator);
    defer std.testing.allocator.free(cwd);

    const repo_root = try findRepoRoot(std.testing.allocator, testing_io, cwd);
    defer std.testing.allocator.free(repo_root);

    const cmd = try gitInDir(std.testing.allocator, testing_io, repo_root, &[_][]const u8{"version"});
    defer std.testing.allocator.free(cmd.stdout);
    defer std.testing.allocator.free(cmd.stderr);

    try std.testing.expectEqual(cmd.term.exited, 0);
    std.debug.print("stdout: {s}\n", .{cmd.stdout});
}

test "call repo object methods" {
    const testing_io = std.testing.io;

    const cwd = try std.process.currentPathAlloc(testing_io, std.testing.allocator);
    defer std.testing.allocator.free(cwd);

    var repo = try Repo.discover(std.testing.allocator, testing_io, cwd);
    defer repo.deinit();

    const branch = try repo.getCurrentBranch();
    defer std.testing.allocator.free(branch);

    const change_state = try repo.diffState();
    std.debug.print("count changes: +{d} -{d}\n", .{ change_state.insertions, change_state.deletions });
}
