const std = @import("std");
const http = std.http;
const models = @import("models.zig");
const downloader = @import("downloader.zig");

pub const Context = struct {
    backing_allocator: std.mem.Allocator,
};

pub fn dispatch(ctx: Context, res: *http.Server.Response) !void {
    var arena = std.heap.ArenaAllocator.init(ctx.backing_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try res.wait();

    if (std.mem.eql(u8, res.request.head.target, "/api/health")) {
        try respondJson(res, .{ .status = "ok", .mode = "parked" });
        
    // 1. New Route: Refresh Data
    } else if (std.mem.eql(u8, res.request.head.target, "/api/admin/refresh") and res.request.head.method == .POST) {
        try handleRefresh(res, allocator);

    } else if (std.mem.eql(u8, res.request.head.target, "/api/routes/find") and res.request.head.method == .POST) {
        try handleFindRoutes(res, allocator);
    } else {
        res.status = .not_found;
        try res.do();
        try res.writeAll("Not Found");
        try res.finish();
    }
}

// 2. New Handler Function
fn handleRefresh(res: *http.Server.Response, allocator: std.mem.Allocator) !void {
    // Call the downloader module
    // Note: In production, you might want to do this in a thread, 
    // but for "parking mode", blocking is fine and simpler.
    const result_json = downloader.refreshData(allocator) catch |err| {
        std.log.err("Download failed: {}", .{err});
        res.status = .internal_server_error;
        try res.do();
        try res.writeAll("{\"error\": \"Download failed\"}");
        try res.finish();
        return;
    };
    
    // Send back the stats (bytes downloaded)
    res.status = .ok;
    res.transfer_encoding = .chunked;
    try res.headers.append("Content-Type", "application/json");
    try res.do();
    try res.writeAll(result_json);
    try res.finish();
}

fn handleFindRoutes(res: *http.Server.Response, allocator: std.mem.Allocator) !void {
    const reader = try res.request.reader();
    const body = try reader.readAllAlloc(allocator, 8192);

    const parsed = std.json.parseFromSlice(models.RouteRequest, allocator, body, .{}) catch {
        res.status = .bad_request;
        try res.do();
        try res.writeAll("Invalid JSON");
        try res.finish();
        return;
    };

    var list = std.ArrayList(models.RouteResult).init(allocator);
    try list.append(.{
        .Origin = parsed.value.origin,
        .Destination = parsed.value.destination,
        .RouteString = "PARKED.ROUTE.V1 (Data Refresh Available)",
        .Source = "System Message",
    });

    try respondJson(res, list.items);
}

fn respondJson(res: *http.Server.Response, data: anytype) !void {
    res.status = .ok;
    res.transfer_encoding = .chunked;
    try res.headers.append("Content-Type", "application/json");
    try res.do();
    try std.json.stringify(data, .{}, res.writer());
    try res.finish();
}