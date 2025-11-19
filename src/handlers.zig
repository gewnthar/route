const std = @import("std");
const http = std.http;
const database = @import("database.zig");
const models = @import("models.zig");

// This struct holds the dependencies the handlers need to work
pub const Context = struct {
    db: *database.DB,
    // We keep a reference to the main allocator to create Arenas
    backing_allocator: std.mem.Allocator,
};

// The main dispatch function acting as a Router
pub fn dispatch(ctx: Context, req: *http.Server.Request) !void {
    // PERF: Create a temporary memory arena just for this request.
    // When this function exits, ALL memory used for parsing JSON and DB rows is freed instantly.
    var arena = std.heap.ArenaAllocator.init(ctx.backing_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Simple Routing Logic
    if (std.mem.eql(u8, req.target, "/api/health")) {
        try handleHealth(req);
    } else if (std.mem.eql(u8, req.target, "/api/routes/find") and req.head.method == .POST) {
        try handleFindRoutes(ctx, req, allocator);
    } else {
        try req.respond("Not Found", .{ .status = .not_found });
    }
}

fn handleHealth(req: *http.Server.Request) !void {
    try req.headers.append("Content-Type", "application/json");
    try req.respond("{\"status\":\"ok\"}", .{ .status = .ok });
}

fn handleFindRoutes(ctx: Context, req: *http.Server.Request, allocator: std.mem.Allocator) !void {
    // 1. Read the body
    const reader = try req.reader();
    const body = try reader.readAllAlloc(allocator, 8192);

    // 2. Parse JSON Request
    const parsed = std.json.parseFromSlice(models.RouteRequest, allocator, body, .{}) catch {
        try req.respond("Invalid JSON", .{ .status = .bad_request });
        return;
    };

    // 3. Call Database Layer
    // Note: We pass the arena allocator so db strings are allocated in temp memory
    const routes = try ctx.db.findPreferredRoutes(allocator, parsed.value.origin, parsed.value.destination);

    // 4. Convert Response to JSON
    try req.headers.append("Content-Type", "application/json");
    const json_response = try std.json.stringifyAlloc(allocator, routes.items, .{});
    
    // 5. Send
    try req.respond(json_response, .{ .status = .ok });
}