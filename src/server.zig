// src/server.zig
// -----------------------------------------------------------------------------
// FAA Route Finder — POSIX HTTP listener and tiny router (Zig 0.15.1)
// Listens on cfg.port, accepts connections, parses the request line, and
// routes to:
//   - GET  /api/health          -> 200 {"status":"ok"}
//   - POST /api/admin/refresh   -> handlers.handleRefresh(allocator, fd)
//   - OPTIONS * (CORS preflight)-> 204
// Anything else -> 404
//
// This file purposely does NOT use std.http.Server (to avoid 0.15.1 API churn).
// It uses std.posix sockets and writes raw HTTP responses.
//
// Depends on:
//   - src/config.zig   (for Config { port: u16 })
//   - src/handlers.zig (for handleRefresh(allocator, fd))
// -----------------------------------------------------------------------------

const std = @import("std");
const posix = std.posix;
const config = @import("config.zig");
const handlers = @import("handlers.zig");

pub const Server = struct {
    allocator: std.mem.Allocator,
    cfg: config.Config,

    const Self = @This();

    pub fn new(allocator: std.mem.Allocator, cfg: config.Config) Self {
        return .{
            .allocator = allocator,
            .cfg = cfg,
        };
    }

    pub fn listen(self: *Self) !void {
        const sock = try posix.socket(posix.AF.INET, posix.SOCK.STREAM, 0);
        defer posix.close(sock);

        // SO_REUSEADDR
        {
            var yes: i32 = 1;
            try posix.setsockopt(
                sock,
                posix.SOL.SOCKET,
                posix.SO.REUSEADDR,
                std.mem.asBytes(&yes),
            );
        }

        // bind 0.0.0.0:<port>
        var addr = posix.sockaddr.in{
            .family = posix.AF.INET,
            .port = std.mem.nativeToBig(u16, self.cfg.port),
            .addr = 0,                // INADDR_ANY == 0
            .zero = .{0} ** 8,
        };
        try posix.bind(
            sock,
            @as(*const posix.sockaddr, @ptrCast(&addr)),
            @sizeOf(posix.sockaddr.in),
        );

        try posix.listen(sock, 128);
        std.debug.print("routes_app listening on 0.0.0.0:{d}\n", .{ self.cfg.port });

        while (true) {
            const conn_fd = try posix.accept(sock, null, null, 0);
            self.handleConnectionFd(conn_fd) catch |e| {
                std.debug.print("conn error: {s}\n", .{ @errorName(e) });
            };
            posix.close(conn_fd);
        }
    }

    fn handleConnectionFd(self: *Self, conn_fd: std.posix.fd_t) !void {
        // Read request (up to 16 KiB, stop at \r\n\r\n)
        var buf: [16 * 1024]u8 = undefined;
        var used: usize = 0;

        while (used < buf.len) {
            const n = posix.read(conn_fd, buf[used..]) catch |e| switch (e) {
                error.WouldBlock => continue,
                else => return e,
            };
            if (n == 0) break;
            used += n;
            if (findHeaderEnd(buf[0..used])) break;
        }

        const req_bytes = buf[0..used];
        const req = parseRequestLine(req_bytes) catch {
            return try writeResponseFd(conn_fd, 400, "text/plain; charset=utf-8", "Bad Request\n", .{ .cors = true });
        };

        // CORS preflight
        if (std.mem.eql(u8, req.method, "OPTIONS")) {
            return try writeResponseFd(conn_fd, 204, "text/plain; charset=utf-8", "", .{ .cors = true });
        }

        // Routes
        if (std.mem.eql(u8, req.method, "GET") and std.mem.eql(u8, req.path, "/api/health")) {
            return try writeResponseFd(conn_fd, 200, "application/json", "{\"status\":\"ok\"}\n", .{ .cors = true });
        } else if (std.mem.eql(u8, req.method, "POST") and std.mem.eql(u8, req.path, "/api/admin/refresh")) {
            // Let the handler do the heavy work and write to this connection.
            return handlers.handleRefresh(self.allocator, conn_fd);
        } else {
            return try writeResponseFd(conn_fd, 404, "text/plain; charset=utf-8", "Not Found\n", .{ .cors = true });
        }
    }
};

// -------------------------
// Minimal HTTP parsing & writing
// -------------------------

fn findHeaderEnd(b: []const u8) bool {
    if (b.len < 4) return false;
    var i: usize = 3;
    while (i < b.len) : (i += 1) {
        if (b[i - 3] == '\r' and b[i - 2] == '\n' and b[i - 1] == '\r' and b[i] == '\n') return true;
    }
    return false;
}

const RequestLine = struct {
    method: []const u8,
    path: []const u8,
    version: []const u8,
};

fn parseRequestLine(b: []const u8) !RequestLine {
    const nl = std.mem.indexOf(u8, b, "\r\n") orelse return error.BadRequest;
    const line = b[0..nl];

    var it = std.mem.splitScalar(u8, line, ' ');
    const method = it.next() orelse return error.BadRequest;
    const path = it.next() orelse return error.BadRequest;
    const version = it.next() orelse return error.BadRequest;

    return .{ .method = method, .path = path, .version = version };
}

const WriteOpts = struct { cors: bool = false };

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

    // end headers
    try writeFmt(fd, "\r\n", .{});

    if (body.len > 0) {
        _ = try posix.write(fd, body);
    }
}

fn writeFmt(fd: std.posix.fd_t, comptime fmt: []const u8, args: anytype) !void {
    var buf: [1024]u8 = undefined; // plenty for each header line
    const s = try std.fmt.bufPrint(&buf, fmt, args);
    _ = try posix.write(fd, s);
}

fn statusText(code: u16) []const u8 {
    return switch (code) {
        200 => "OK",
        204 => "No Content",
        400 => "Bad Request",
        404 => "Not Found",
        405 => "Method Not Allowed",
        else => "OK",
    };
}
