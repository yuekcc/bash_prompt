const std = @import("std");
const builtin = @import("builtin");
const process = std.process;
const known_folders = @import("known_folders");

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
    if (builtin.os.tag == .windows) {
        return "\\";
    } else {
        return "/";
    }
}

fn printInstallScript(writer: *ErrorIgnoreWriter, exe_name: []const u8) !void {
    const script = "\nPROMPT_COMMAND=\"{s}\"; export PROMPT_COMMAND; PS1=\"\\$ \";";
    writer.print(script, .{exe_name});
}

const ShellPrompt = struct {
    allocator: std.mem.Allocator,
    output: *ErrorIgnoreWriter,
    use_short_path: bool,
    use_env: bool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, writer: *ErrorIgnoreWriter, cli_flag: *CliFlag) ShellPrompt {
        const self: Self = .{ .allocator = allocator, .output = writer, .use_env = cli_flag.use_env, .use_short_path = cli_flag.use_short_path };

        return self;
    }

    pub fn deinit(_: *Self) void {}

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
        const cwd = try process.getCwdAlloc(self.allocator);
        const home_dir = try known_folders.getPath(self.allocator, .home);
        const updated_pwd = try std.mem.replaceOwned(u8, self.allocator, cwd, home_dir.?, "~");

        var iter = std.mem.splitSequence(u8, updated_pwd, getPathDelimiter());
        var path_buf = std.ArrayList([]const u8).init(self.allocator);

        while (iter.next()) |p| {
            const str = try self.allocator.dupe(u8, p);
            try path_buf.append(str);
        }

        if (self.use_short_path) {
            for (0..path_buf.items.len) |i| {
                if (i == 0 or i == path_buf.items.len - 1) {
                    continue;
                }

                path_buf.items[i] = try self.allocator.dupe(u8, utf8.charAt(path_buf.items[i], 0).?);
            }
        }

        const formatted = try path_buf.toOwnedSlice();
        const pwd_display = try std.mem.join(self.allocator, "/", formatted);

        self.output.print("\r\n", .{});
        self.output.print(styles.fg_blue ++ "{s}" ++ styles.sgr_reset, .{pwd_display});
    }

    fn printEnv(self: *Self) !void {
        var env_map = try process.getEnvMap(self.allocator);
        defer env_map.deinit();

        var iter = env_map.iterator();
        while (iter.next()) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;

            if (std.mem.startsWith(u8, key, "BS_ENV_")) {
                self.output.print(" ({s})", .{value});
            }
        }
    }

    fn printGitStatus(self: *Self) !void {
        var repo = Repo.discover(self.allocator) catch return;
        defer repo.deinit();

        const branch_name = repo.getCurrentBranch() catch return;
        if (branch_name.len > 0) {
            self.output.print(" @ ", .{});
            self.output.print(styles.fg_yellow ++ "{s}" ++ styles.sgr_reset, .{branch_name});

            const changes = repo.getChanges() catch return;
            if (changes.len > 0) {
                self.output.print(styles.fg_red ++ "*" ++ styles.sgr_reset, .{});

                const change_count = repo.countChanges() catch "";

                self.output.print(" {s}", .{change_count});
            }
        }
    }
};

fn parseCliFlag(allocator: std.mem.Allocator) !*CliFlag {
    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    const exe_name = args_iter.next().?;

    var out = try allocator.create(CliFlag);
    out.exe_name = try allocator.dupe(u8, exe_name);
    out.show_init = false;
    out.use_short_path = false;

    while (args_iter.next()) |flag| {
        if (std.mem.eql(u8, flag, "init")) {
            out.show_init = true;
        } else if (std.mem.eql(u8, flag, "--short")) {
            out.use_short_path = true;
        } else if (std.mem.eql(u8, flag, "--show-env")) {
            out.use_env = true;
        }
    }

    return out;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    var writer = ErrorIgnoreWriter.init();
    defer writer.close();

    const cli_flag = try parseCliFlag(allocator);
    defer allocator.destroy(cli_flag);

    if (cli_flag.show_init) {
        try printInstallScript(&writer, cli_flag.exe_name);
        return;
    }

    var prompt = ShellPrompt.init(allocator, &writer, cli_flag);
    try prompt.print();
    prompt.deinit();
}

test "find home dir" {
    const home_dir = try known_folders.getPath(std.testing.allocator, .home);
    defer std.testing.allocator.free(home_dir.?);

    std.debug.print("home dir: {s}\n", .{home_dir.?});
}
