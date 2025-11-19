const std = @import("std");
const myzql = @import("myzql");
const models = @import("models.zig");
// We import the Config struct type to know what to expect in init
const Config = @import("config.zig").Config;

pub const DB = struct {
    pool: myzql.Pool,

    pub fn init(allocator: std.mem.Allocator, conf: Config) !DB {
        const pool = try myzql.Pool.init(allocator, .{
            .host = conf.db_host,
            .port = conf.db_port,
            .user = conf.db_user,
            .password = conf.db_password,
            .database = conf.db_name,
            .size = 10, // Max open connections
        });
        return DB{ .pool = pool };
    }

    pub fn deinit(self: *DB) void {
        self.pool.deinit();
    }

    pub fn findPreferredRoutes(self: *DB, allocator: std.mem.Allocator, origin: []const u8, dest: []const u8) !std.ArrayList(models.RouteResult) {
        // 1. Get a connection
        const conn = try self.pool.acquire();
        defer self.pool.release(conn);

        // 2. Prepare SQL
        // We select route_string. Source is hardcoded for this specific table query for simplicity
        var stmt = try conn.prepare("SELECT route_string, 'Preferred' as source FROM nfdc_preferred_routes WHERE origin = ? AND destination = ?");
        defer stmt.deinit();

        // 3. Execute
        const rows = try stmt.execute(.{ origin, dest });
        
        // 4. Parse Results
        var results = std.ArrayList(models.RouteResult).init(allocator);
        while (try rows.next()) |row| {
            try results.append(.{
                .Origin = origin,
                .Destination = dest,
                // row.get allocates the string into the provided 'allocator' (our request arena)
                .RouteString = row.get(0, []const u8), 
                .Source = row.get(1, []const u8),
            });
        }
        return results;
    }
};