const std = @import("std");
const config_mod = @import("config.zig");
const database_mod = @import("database.zig");
const server_mod = @import("server.zig");
const handlers_mod = @import("handlers.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    const config = try config_mod.load(allocator, ".env");
    std.log.info("Booting... DB User: {s}", .{config.db_user});

    var db = try database_mod.DB.init(allocator, config);
    defer db.deinit();

    const ctx = handlers_mod.Context{ 
        .db = &db, 
        .backing_allocator = allocator 
    };

    try server_mod.start(allocator, config.server_port, ctx);
}