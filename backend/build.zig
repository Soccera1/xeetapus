const std = @import("std");

pub fn build(b: *std.Build) void {
    var target_query = b.standardTargetOptionsQueryOnly(.{});
    if (target_query.os_tag == null) {
        target_query.os_tag = .linux;
    }
    if (target_query.abi == null) {
        target_query.abi = .gnu;
    }
    if (target_query.os_tag == .linux and target_query.dynamic_linker.get() == null) {
        target_query.dynamic_linker = std.Target.DynamicLinker.init("/lib64/ld-linux-x86-64.so.2");
    }
    const target = b.resolveTargetQuery(target_query);
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "xeetapus-backend",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.addIncludePath(.{ .cwd_relative = "/usr/include" });
    exe.root_module.addLibraryPath(.{ .cwd_relative = "/usr/lib64" });
    exe.root_module.linkSystemLibrary("sqlite3", .{});
    exe.root_module.link_libc = true;

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
