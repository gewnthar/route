const std = @import("std");
const config_mod = @import("config.zig");
const database_mod = @import("database.zig");
const server_mod = @import("server.zig");
const handlers_mod = @import("handlers.zig");

pub fn main() !void {
    // 1. Setup General Purpose Allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    // 2. Load Configuration
    const config = try config_mod.load(allocator, ".env");
    std.log.info("Booting up... DB User: {s}", .{config.db_user});

    // 3. Initialize Database
    var db = try database_mod.DB.init(allocator, config);
    defer db.deinit();

    // 4. Setup Context
    // This bundle of state is passed to every request
    const ctx = handlers_mod.Context{ 
        .db = &db, 
        .backing_allocator = allocator 
    };

    // 5. Start Server
    // This blocks forever
    try server_mod.start(allocator, config.server_port, ctx);
}