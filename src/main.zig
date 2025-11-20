const std = @import("std");
const net = std.net;
const http = std.http;
const config_mod = @import("config.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Keep config loading so we know .env parsing works for 0.16
    const config = try config_mod.load(allocator, ".env");
    
    const address = try net.Address.parseIp4("127.0.0.1", config.server_port);
    var server = try http.Server.init(allocator, .{ .reuse_address = true });
    defer server.deinit();

    std.log.info("Routes App (Holding Pattern) listening on {d}...", .{config.server_port});
    try server.listen(address);

    while (true) {
        var res = try server.accept(.{ .allocator = allocator });
        try handleRequest(&res);
    }
}

fn handleRequest(res: *http.Server.Response) !void {
    try res.wait();
    // Just a simple health check for now
    if (std.mem.eql(u8, res.request.head.target, "/api/health")) {
        res.status = .ok;
        res.transfer_encoding = .chunked;
        try res.headers.append("Content-Type", "application/json");
        try res.do();
        try res.writeAll("{\"status\": \"waiting_for_zig_0.16\"}");
        try res.finish();
    } else {
        res.status = .not_found;
        try res.do();
        try res.finish();
    }
}