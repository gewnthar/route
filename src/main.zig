const std = @import("std");
const config_mod = @import("config.zig");
const server_mod = @import("server.zig");
const handlers_mod = @import("handlers.zig");

// Kept for future use
const models_mod = @import("models.zig"); 

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    // 1. Load Config (Keeps env parsing active)
    const config = try config_mod.load(allocator, ".env");
    std.log.info("Config loaded. Port: {d}", .{config.server_port});

    // 2. Setup Context (No DB)
    const ctx = handlers_mod.Context{ 
        .backing_allocator = allocator 
    };

    // 3. Start Server
    try server_mod.start(allocator, config.server_port, ctx);
}