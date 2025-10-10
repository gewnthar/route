// SPDX-License-Identifier: MIT
// File: src/handlers.zig
//
// FAA Route Finder — Endpoint handlers & tiny HTTP writer.
//
// Endpoints:
//   handleHealth   -> 200 {"status":"ok"}
//   handleRefresh  -> downloads FAA CSVs to ./data, returns sizes
//   handleOptions  -> 204 (CORS preflight)
//   handleNotFound -> 404
//
// HTTP Writer:
// - Minimal helpers to print status line, headers, and body over a fd.
// - Adds CORS headers by default (WriteOpts.cors = true).
//
// See also:
//   src/downloader.zig   # CSV downloader via std.http.Client.fetch


const std = @import("std");
const downloader = @import("downloader.zig");

pub const WriteOpts = struct { cors: bool = true };

pub fn handleHealth(fd: std.posix.fd_t) !void {
    try writeResponseFd(fd, 200, "application/json", "{\"status\":\"ok\"}\n", .{});
}

pub fn handleRefresh(allocator: std.mem.Allocator, fd: std.posix.fd_t) !void {
    const json = downloader.refreshData(allocator) catch |err| {
        const msg = std.fmt.allocPrint(allocator, "{{\"error\":\"{s}\"}}\n", .{@errorName(err)}) catch "{\"error\":\"oom\"}\n";
        defer if (msg.ptr != "{\"error\":\"oom\"}\n".ptr) allocator.free(msg);
        return writeResponseFd(fd, 500, "application/json", msg, .{});
    };
    defer allocator.free(json);
    try writeResponseFd(fd, 200, "application/json", json, .{});
}

pub fn handleOptions(fd: std.posix.fd_t) !void {
    try writeResponseFd(fd, 204, "text/plain; charset=utf-8", "", .{});
}

pub fn handleNotFound(fd: std.posix.fd_t) !void {
    try writeResponseFd(fd, 404, "text/plain; charset=utf-8", "Not Found\n", .{});
}

// ---- tiny HTTP writer (same as what worked before)

fn writeResponseFd(fd: std.posix.fd_t, code: u16, content_type: []const u8, body: []const u8, opts: WriteOpts) !void {
    try writeFmt(fd, "HTTP/1.1 {d} {s}\r\n", .{ code, statusText(code) });
    try writeFmt(fd, "Content-Type: {s}\r\n", .{ content_type });
    try writeFmt(fd, "Content-Length: {d}\r\n", .{ body.len });
    try writeFmt(fd, "Connection: close\r\n", .{});
    if (opts.cors) {
        try writeFmt(fd, "Access-Control-Allow-Origin: *\r\n", .{});
        try writeFmt(fd, "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n", .{});
        try writeFmt(fd, "Access-Control-Allow-Headers: content-type\r\n", .{});
    }
    try writeFmt(fd, "\r\n", .{});
    if (body.len > 0) _ = try std.posix.write(fd, body);
}

fn writeFmt(fd: std.posix.fd_t, comptime fmt: []const u8, args: anytype) !void {
    var buf: [1024]u8 = undefined;
    const s = try std.fmt.bufPrint(&buf, fmt, args);
    _ = try std.posix.write(fd, s);
}

fn statusText(code: u16) []const u8 {
    return switch (code) {
        200 => "OK",
        204 => "No Content",
        404 => "Not Found",
        405 => "Method Not Allowed",
        else => "OK",
    };
}
