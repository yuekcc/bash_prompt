const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const known_folders = b.dependency("known_folders", .{}).module("known-folders");

    const app = b.addExecutable(.{
        .name = "bash_prompt",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = true,
        .single_threaded = true,
    });
    app.root_module.addImport("known_folders", known_folders);

    b.installArtifact(app);

    // zig build run
    {
        const run_cmd = b.addRunArtifact(app);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    // zig build test
    {
        const test_step = b.step("test", "Run unit tests");

        const tests = b.addTest(.{ .root_source_file = b.path("src/tests.zig") });
        tests.root_module.addImport("known_folders", known_folders);
        const run_tests = b.addRunArtifact(tests);

        test_step.dependOn(&run_tests.step);
    }
}
