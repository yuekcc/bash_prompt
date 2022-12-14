const std = @import("std");

const vendors = struct {
    pub const knownFolders = std.build.Pkg{
        .name = "known-folders",
        .source = std.build.FileSource{
            .path = "vendors/known-folders/known-folders.zig",
        },
    };
};

pub fn build(b: *std.build.Builder) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("bash_prompt", "src/main.zig");
    exe.addPackage(vendors.knownFolders);

    exe.single_threaded = true;
    exe.strip = mode != .Debug;
    exe.want_lto = mode != .Debug;
    exe.setBuildMode(mode);
    exe.setTarget(target);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/tests.zig");
    exe_tests.addPackage(vendors.knownFolders);
    exe_tests.setBuildMode(mode);
    exe_tests.setTarget(target);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
