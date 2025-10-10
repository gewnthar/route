// SPDX-License-Identifier: MIT
// File: src/config.zig
//
// FAA Route Finder — Configuration loader.
//
// - Reads port from (in order):
//     1) PORT
//     2) SERVER_PORT
//     3) .env (same keys)
//     4) default 8080
//
// .env example:
//   PORT=8080
//   # or
//   SERVER_PORT=8080
//
// Exposes:
//   pub const Config = struct { port: u16 };
//   pub fn load(allocator) !Config
//
// See also:
//   src/main.zig


const std = @import("std");

pub const Config = struct {
    port: u16,
};

pub fn load(allocator: std.mem.Allocator) !Config {
    const port = try readPortFromEnvOrDefault(allocator, 8080);
    return .{ .port = port };
}

fn readPortFromEnvOrDefault(allocator: std.mem.Allocator, default_port: u16) !u16 {
    if (std.process.getEnvVarOwned(allocator, "PORT")) |p| {
        defer allocator.free(p);
        if (parsePort(p)) |v| return v;
    } else |_| {}

    if (std.process.getEnvVarOwned(allocator, "SERVER_PORT")) |p| {
        defer allocator.free(p);
        if (parsePort(p)) |v| return v;
    } else |_| {}

    if (try readDotEnvPort(allocator)) |v| return v;

    return default_port;
}

fn parsePort(s: []const u8) ?u16 {
    const val = std.fmt.parseInt(u32, s, 10) catch return null;
    if (val == 0 or val > 65535) return null;
    return @as(u16, @intCast(val));
}

fn readDotEnvPort(allocator: std.mem.Allocator) !?u16 {
    var file = std.fs.cwd().openFile(".env", .{}) catch return null;
    defer file.close();

    const data = try file.readToEndAlloc(allocator, 64 * 1024);
    defer allocator.free(data);

    var it = std.mem.splitScalar(u8, data, '\n');
    while (it.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        if (std.mem.startsWith(u8, trimmed, "PORT=")) {
            const value = std.mem.trim(u8, trimmed["PORT=".len..], " \t\r");
            if (parsePort(value)) |p| return p;
        } else if (std.mem.startsWith(u8, trimmed, "SERVER_PORT=")) {
            const value = std.mem.trim(u8, trimmed["SERVER_PORT=".len..], " \t\r");
            if (parsePort(value)) |p| return p;
        }
    }
    return null;
}
