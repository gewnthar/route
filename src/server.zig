const std = @import("std");
const http = std.http;
const net = std.net;
const handlers = @import("handlers.zig");

pub fn start(allocator: std.mem.Allocator, port: u16, ctx: handlers.Context) !void {
    // 1. Define Address
    const address = try net.Address.parseIp4("127.0.0.1", port);
    
    // 2. Initialize Server
    var server = try http.Server.init(allocator, .{ .reuse_address = true });
    defer server.deinit();

    std.log.info("Server listening on 127.0.0.1:{d}", .{port});
    
    // 3. Bind and Listen
    try server.listen(address);

    // 4. Accept Loop
    while (true) {
        // accept() allocates memory for the connection details
        var res = try server.accept(.{ .allocator = allocator });
        
        // We treat the response object as the handle for the connection.
        // In a threaded server, you would spawn a thread here.
        // For now, we call dispatch directly.
        handlers.dispatch(ctx, &res) catch |err| {
            std.log.err("Request failed: {}", .{err});
            // Ensure we clean up if dispatch fails
            if (res.state != .finished) {
                res.deinit(); 
            }
        };
    }
}