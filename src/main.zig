const std = @import("std");
const posix = std.posix;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const gpa_alloc = gpa.allocator();

    const port = try readPortFromEnvOrDefault(gpa_alloc, 8080);

    // ---- TCP listener (POSIX) ----
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

    // bind 0.0.0.0:port
    var addr = posix.sockaddr.in{
        .family = posix.AF.INET,
        .port = std.mem.nativeToBig(u16, port), // htons
        .addr = 0, // 0.0.0.0
        .zero = .{0} ** 8,
    };
    try posix.bind(
        sock,
        @as(*const posix.sockaddr, @ptrCast(&addr)),
        @sizeOf(posix.sockaddr.in),
    );

    try posix.listen(sock, 128);
    std.debug.print("routes_app listening on 0.0.0.0:{d}\n", .{port});

    while (true) {
        const conn_fd = try posix.accept(sock, null, null, 0);
        handleConnectionFd(gpa_alloc, conn_fd) catch |e| {
            std.debug.print("conn error: {s}\n", .{@errorName(e)});
        };
        posix.close(conn_fd);
    }
}

fn handleConnectionFd(allocator: std.mem.Allocator, conn_fd: std.posix.fd_t) !void {
    // Read request (up to 16 KiB, stop at \r\n\r\n)
    var buf: [16 * 1024]u8 = undefined;
    var used: usize = 0;

    while (used < buf.len) {
        const n = std.posix.read(conn_fd, buf[used..]) catch |e| switch (e) {
            error.WouldBlock => continue,
            else => return e,
        };
        if (n == 0) break;
        used += n;
        if (findHeaderEnd(buf[0..used])) break;
    }

    const req_bytes = buf[0..used];
    const req = try parseRequestLine(req_bytes);

    // CORS preflight
    if (std.mem.eql(u8, req.method, "OPTIONS")) {
        return try writeResponseFd(conn_fd, 204, "text/plain; charset=utf-8", "", .{ .cors = true });
    }

    // Routes
    if (std.mem.eql(u8, req.method, "GET") and std.mem.eql(u8, req.path, "/api/health")) {
        return try writeResponseFd(conn_fd, 200, "application/json", "{\"status\":\"ok\"}\n", .{ .cors = true });
    } else if (std.mem.eql(u8, req.method, "POST") and std.mem.eql(u8, req.path, "/api/admin/refresh")) {
        const json = try refreshData(allocator);
        defer allocator.free(json);
        return try writeResponseFd(conn_fd, 200, "application/json", json, .{ .cors = true });
    } else {
        return try writeResponseFd(conn_fd, 404, "text/plain; charset=utf-8", "Not Found\n", .{ .cors = true });
    }
}

fn findHeaderEnd(b: []const u8) bool {
    if (b.len < 4) return false;
    var i: usize = 3;
    while (i < b.len) : (i += 1) {
        if (b[i-3] == '\r' and b[i-2] == '\n' and b[i-1] == '\r' and b[i] == '\n')
            return true;
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
    try writeFmt(fd, "\r\n", .{}); // end headers
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

// -------------------------
// ENV / CONFIG
// -------------------------

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

// -------------------------
// REFRESH / DOWNLOAD
// -------------------------

fn refreshData(allocator: std.mem.Allocator) ![]u8 {
    try ensureDataDir();

    const PREF_URL = "https://www.fly.faa.gov/rmt/data_file/prefroutes_db.csv";
    const CDR_URL  = "https://www.fly.faa.gov/rmt/data_file/codedswap_db.csv";

    const pref_path = "data/prefroutes_db.csv";
    const cdr_path  = "data/codedswap_db.csv";

    const pref_bytes = try downloadToFile(allocator, PREF_URL, pref_path);
    const cdr_bytes  = try downloadToFile(allocator, CDR_URL,  cdr_path);

    return try std.fmt.allocPrint(allocator,
        "{{\"prefroutes_bytes\":{d},\"cdr_bytes\":{d}}}\n",
        .{ pref_bytes, cdr_bytes }
    );
}

fn ensureDataDir() !void {
    std.fs.cwd().makeDir("data") catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };
}

// **Correct for Zig 0.15.1**: use Client.fetch + a File writer as response_writer.
fn downloadToFile(allocator: std.mem.Allocator, url: []const u8, out_path: []const u8) !usize {
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    var file = try std.fs.cwd().createFile(out_path, .{ .truncate = true });
    defer file.close();

    var out_buf: [64 * 1024]u8 = undefined;
    var file_writer = file.writer(&out_buf);
    const w = &file_writer.interface;

    // 0.15.1: one-shot request with streaming writer; no redirect field, no deinit
    const res = try client.fetch(.{
        .method = .GET,
        .location = .{ .url = url },
        .response_writer = w,
        .keep_alive = false,
    });

    // optional status guard (FetchResult exposes a status)
    if (res.status != .ok) return error.UnexpectedStatus;

    // flush buffered writer before stat()
    try w.flush();

    const st = try file.stat();
    return @as(usize, @intCast(st.size));
}