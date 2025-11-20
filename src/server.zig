const std = @import("std");
const http = std.http;
const net = std.net;
const handlers = @import("handlers.zig");

pub fn start(allocator: std.mem.Allocator, port: u16, ctx: handlers.Context) !void {
    const address = try net.Address.parseIp4("127.0.0.1", port);
    
    var server = try http.Server.init(allocator, .{ .reuse_address = true });
    defer server.deinit();

    std.log.info("Server listening on 127.0.0.1:{d} (Parked Mode)", .{port});
    try server.listen(address);

    while (true) {
        var res = try server.accept(.{ .allocator = allocator });
        
        handlers.dispatch(ctx, &res) catch |err| {
            std.log.err("Request error: {}", .{err});
            if (res.state != .finished) res.deinit();
        };
    }
}