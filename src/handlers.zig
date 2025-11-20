const std = @import("std");
const http = std.http;
const database = @import("database.zig");
const models = @import("models.zig");

pub const Context = struct {
    db: *database.DB,
    backing_allocator: std.mem.Allocator,
};

pub fn dispatch(ctx: Context, res: *http.Server.Response) !void {
    var arena = std.heap.ArenaAllocator.init(ctx.backing_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try res.wait();

    if (std.mem.eql(u8, res.request.head.target, "/api/health")) {
        try respondJson(res, .{ .status = "ok" });
    } else if (std.mem.eql(u8, res.request.head.target, "/api/routes/find") and res.request.head.method == .POST) {
        try handleFindRoutes(ctx.db, res, allocator);
    } else {
        res.status = .not_found;
        try res.do();
        try res.writeAll("Not Found");
        try res.finish();
    }
}

fn handleFindRoutes(db: *database.DB, res: *http.Server.Response, allocator: std.mem.Allocator) !void {
    const reader = try res.request.reader();
    const body = try reader.readAllAlloc(allocator, 8192);

    const parsed = std.json.parseFromSlice(models.RouteRequest, allocator, body, .{}) catch {
        res.status = .bad_request;
        try res.do();
        try res.writeAll("Invalid JSON");
        try res.finish();
        return;
    };

    const routes = try db.findPreferredRoutes(allocator, parsed.value.origin, parsed.value.destination);
    try respondJson(res, routes.items);
}

fn respondJson(res: *http.Server.Response, data: anytype) !void {
    res.status = .ok;
    res.transfer_encoding = .chunked;
    try res.headers.append("Content-Type", "application/json");
    try res.do();
    try std.json.stringify(data, .{}, res.writer());
    try res.finish();
}