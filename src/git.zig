const std = @import("std");
const process = std.process;
const fs = std.fs;
const path = std.fs.path;

const RepoError = error{
    NotFound,
};

pub fn findRepoRoot(allocator: std.mem.Allocator, io: std.Io, start: []const u8) ![]const u8 {
    var current = start;
    var dir: std.Io.Dir = undefined;

    while (true) {
        // 设置一个代码块，用于释放 git_dir
        {
            const git_dir = try path.resolve(allocator, &[_][]const u8{ current, ".git" });
            defer allocator.free(git_dir);

            dir = std.Io.Dir.openDirAbsolute(io, git_dir, .{}) catch {
                const parent_dir = path.dirname(current);

                // 如果 current 是根目录，parent_dir = null
                if (parent_dir == null) {
                    return RepoError.NotFound;
                }

                // 设置为父目录，继续查找 .git 目录
                current = parent_dir.?;
                continue;
            };
        }
        dir.close(io);
        break;
    }

    return allocator.dupe(u8, current);
}

// 用 arena 分配器解决内部内存释放问题
pub fn gitInDir(allocator: std.mem.Allocator, io: std.Io, dir: []const u8, argv: []const []const u8) !process.RunResult {
    var cmd_line = std.array_list.Managed([]const u8).init(allocator);
    defer cmd_line.deinit();

    try cmd_line.appendSlice(&[_][]const u8{ "git", "-C", dir });
    try cmd_line.appendSlice(argv);

    const combined = try cmd_line.toOwnedSlice();
    defer allocator.free(combined);

    return process.run(allocator, io, .{
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

    // 跳过警告信息行
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
        defer allocator.free(repo_dir);

        return Self{
            .allocator = allocator,
            .dir = try allocator.dupe(u8, repo_dir),
            .io = io,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.dir);
    }

    fn git(self: *Self, argv: []const []const u8) ![]const u8 {
        const cmd_result = try gitInDir(self.allocator, self.io, self.dir, argv);
        const cmd_output = if (cmd_result.term.exited == 0) cmd_result.stdout else "";
        defer self.allocator.free(cmd_result.stdout);
        defer self.allocator.free(cmd_result.stderr);

        const result = std.mem.trim(u8, cmd_output, "\n");
        return self.allocator.dupe(u8, result);
    }

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
    var allocator = std.testing.allocator;

    const cwd = try process.getCwdAlloc(allocator);
    defer allocator.free(cwd);

    const repo_root = try findRepoRoot(allocator, cwd);
    defer allocator.free(repo_root);

    std.debug.print("repo_root = {s}\n", .{repo_root});
}

test "execute git cmd in that dir" {
    var allocator = std.testing.allocator;

    const cwd = try process.getCwdAlloc(allocator);
    defer allocator.free(cwd);

    const repo_root = try findRepoRoot(allocator, cwd);
    defer allocator.free(repo_root);

    const cmd = try gitInDir(allocator, repo_root, &[_][]const u8{"version"});
    defer allocator.free(cmd.stdout);
    defer allocator.free(cmd.stderr);

    try std.testing.expectEqual(cmd.term.exited, 0);
    std.debug.print("stdout: {s}\n", .{cmd.stdout});
}

test "call repo object methods" {
    var allocator = std.testing.allocator;
    var repo = try Repo.discover(allocator);
    defer repo.deinit();

    const branch = try repo.getCurrentBranch();
    defer allocator.free(branch);
    std.debug.print("current branch: {s}\n", .{branch});

    const change_state = try repo.diffState();
    std.debug.print("count changes: +{d} -{d}\n", .{ change_state.insertions, change_state.deletions });
}
