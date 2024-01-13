const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const known_folders_module = b.createModule(.{
        .root_source_file = .{ .path = "vendors/known-folders/known-folders.zig" },
    });

    const app = b.addExecutable(.{
        .name = "bash_prompt",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .strip = true,
        .single_threaded = true,
    });
    app.root_module.addImport("known-folders", known_folders_module);

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
        const app_tests = b.addTest(.{ .root_source_file = .{ .path = "src/tests.zig" } });
        app_tests.root_module.addImport("known-folders", known_folders_module);

        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&app_tests.step);
    }
}
