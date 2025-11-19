const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. DEFINE DEPENDENCY
    // This looks at build.zig.zon to find "myzql"
    const myzql_dep = b.dependency("myzql", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "routes_app",
        // 2. ROOT MODULE SETUP
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            // 3. INJECT DEPENDENCY
            // This makes "@import("myzql")" work in your code
            .imports = &.{
                .{ .name = "myzql", .module = myzql_dep.module("myzql") },
            },
        }),
    });

    // Note: We removed exe.linkSystemLibrary("mariadb") because
    // myzql handles the protocol natively in Zig!

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}