const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const myzql_module = b.createModule(.{
        .root_source_file = b.path("libs/myzql/src/myzql.zig"),
    });

    const exe = b.addExecutable(.{
        .name = "routes_app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                // 2. Link the local module so @import("myzql") works
                .{ .name = "myzql", .module = myzql_module },
            },
        }),
    });

    b.installArtifact(exe);
}