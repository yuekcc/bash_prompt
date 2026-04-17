const std = @import("std");
const builtin = @import("builtin");

const styles = @import("styles.zig").styles;
const Repo = @import("git.zig").Repo;
const ErrorIgnoreWriter = @import("ErrorIgnoredWriter.zig");
const utf8 = @import("utf8.zig");

const CliFlag = struct {
    exe_name: []const u8,
    show_init: bool,
    use_short_path: bool,
    use_env: bool,
};

fn getPathDelimiter() []const u8 {
    return if (builtin.os.tag == .windows) "\\" else "/";
}

fn printInstallScript(writer: *ErrorIgnoreWriter, exe_name: []const u8) void {
    writer.print("\nPROMPT_COMMAND=\"{s}\"; export PROMPT_COMMAND; PS1=\"$ \";", .{exe_name});
}

/// 从环境变量获取用户主目录。
/// 返回 owned 字符串，调用者负责释放。
fn getHomeDir(allocator: std.mem.Allocator, environ_map: *std.process.Environ.Map) ![]const u8 {
    if (builtin.os.tag == .windows) {
        if (environ_map.get("USERPROFILE")) |path| {
            return allocator.dupe(u8, path);
        }
    }
    if (environ_map.get("HOME")) |path| {
        return allocator.dupe(u8, path);
    }
    return error.FileNotFound;
}

const ShellPrompt = struct {
    allocator: std.mem.Allocator,
    output: *ErrorIgnoreWriter,
    use_short_path: bool,
    use_env: bool,
    home: []const u8,
    cwd: []const u8,
    io: std.Io,
    environ_map: *std.process.Environ.Map,

    const Self = @This();

    pub fn print(self: *Self) !void {
        try self.printWorkingDir();
        try self.printGitStatus();
        try self.printEnv();
        try self.printEnding();
    }

    fn printEnding(self: *Self) !void {
        self.output.print("\r\n", .{});
    }

    fn printWorkingDir(self: *Self) !void {
        const updated_pwd = try std.mem.replaceOwned(u8, self.allocator, self.cwd, self.home, "~");
        defer self.allocator.free(updated_pwd);

        const delimiter = getPathDelimiter();
        var iter = std.mem.splitSequence(u8, updated_pwd, delimiter);

        var path_buf = std.array_list.Managed([]const u8).init(self.allocator);
        defer path_buf.deinit();

        while (iter.next()) |p| {
            const str = try self.allocator.dupe(u8, p);
            try path_buf.append(str);
        }

        if (self.use_short_path) {
            for (1..path_buf.items.len - 1) |i| {
                path_buf.items[i] = try self.allocator.dupe(u8, utf8.charAt(path_buf.items[i], 0).?);
            }
        }

        const formatted = try path_buf.toOwnedSlice();
        errdefer self.allocator.free(formatted);

        const pwd_display = try std.mem.join(self.allocator, delimiter, formatted);
        errdefer self.allocator.free(pwd_display);

        self.output.print("\r\n", .{});
        self.output.print(styles.fg_blue ++ "{s}" ++ styles.sgr_reset, .{pwd_display});
    }

    fn printEnv(self: *Self) !void {
        if (!self.use_env) {
            return;
        }

        var iter = self.environ_map.iterator();
        while (iter.next()) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;

            if (std.mem.startsWith(u8, key, "BP_ENV_")) {
                self.output.print(" ({s})", .{value});
            }
        }
    }

    fn printGitStatus(self: *Self) !void {
        var repo = Repo.discover(self.allocator, self.io, self.cwd) catch return;
        defer repo.deinit();

        const branch_name = repo.getCurrentBranch() catch return;
        if (branch_name.len > 0) {
            defer self.allocator.free(branch_name);
            self.output.print(" @ ", .{});
            self.output.print(styles.fg_yellow ++ "{s}" ++ styles.sgr_reset, .{branch_name});

            const changes = repo.diffState() catch return;
            if (changes.files_changed > 0) {
                self.output.print(styles.fg_red ++ "*" ++ styles.sgr_reset, .{});
                self.output.print(" +{d}, -{d}", .{ changes.insertions, changes.deletions });
            }
        }
    }
};

fn parseCliFlag(allocator: std.mem.Allocator, args: std.process.Args) !CliFlag {
    var args_iter = try args.iterateAllocator(allocator);
    defer args_iter.deinit();

    const exe_name = args_iter.next().?;
    var show_init = false;
    var use_short_path = false;
    var use_env = false;

    while (args_iter.next()) |flag| {
        if (std.mem.eql(u8, flag, "init")) {
            show_init = true;
        } else if (std.mem.eql(u8, flag, "--short")) {
            use_short_path = true;
        } else if (std.mem.eql(u8, flag, "--venv")) {
            use_env = true;
        }
    }

    const exe_name_dup = try allocator.dupe(u8, exe_name);
    errdefer allocator.free(exe_name_dup);

    return CliFlag{
        .exe_name = exe_name_dup,
        .show_init = show_init,
        .use_short_path = use_short_path,
        .use_env = use_env,
    };
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var buf: [1024]u8 = undefined;
    var file = std.Io.File.stdout();
    defer file.close(io);
    var file_writer = file.writer(io, &buf);

    var writer = ErrorIgnoreWriter.init(&file_writer.interface);
    defer writer.close();

    const cli_flag = try parseCliFlag(gpa, init.minimal.args);
    defer gpa.free(cli_flag.exe_name);

    if (cli_flag.show_init) {
        printInstallScript(&writer, cli_flag.exe_name);
        return;
    }

    const home = try getHomeDir(gpa, init.environ_map);
    defer gpa.free(home);

    const cwd = try std.process.currentPathAlloc(io, gpa);
    defer gpa.free(cwd);

    var prompt = ShellPrompt{
        .allocator = gpa,
        .output = &writer,
        .use_env = cli_flag.use_env,
        .use_short_path = cli_flag.use_short_path,
        .home = home,
        .cwd = cwd,
        .io = io,
        .environ_map = init.environ_map,
    };

    try prompt.print();
}

test "find home dir" {
    var map = try std.testing.environ.createMap(std.testing.allocator);
    defer map.deinit();

    const home_dir = try getHomeDir(std.testing.allocator, &map);
    defer std.testing.allocator.free(home_dir);

    std.debug.print("home dir: {s}\n", .{home_dir});
}
