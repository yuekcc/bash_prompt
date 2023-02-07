const std = @import("std");

const vendors = struct {
    pub const knownFolders = std.build.Pkg{
        .name = "known-folders",
        .source = std.build.FileSource{
            .path = "vendors/known-folders/known-folders.zig",
        },
    };
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const knownFolders = b.createModule(.{
        .source_file = .{ .path = "vendors/known-folders/known-folders.zig" },
    });

    const exe = b.addExecutable(.{
        .name = "bash_prompt",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.single_threaded = true;
    exe.strip = optimize != .Debug;
    exe.want_lto = optimize != .Debug;
    exe.addModule("known-folders", knownFolders);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest(.{ .root_source_file = .{ .path = "src/tests.zig" } });
    exe_tests.addModule("known-folders", knownFolders);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
