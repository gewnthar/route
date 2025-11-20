const std = @import("std");
const myzql = @import("myzql");
const models = @import("models.zig");
const Config = @import("config.zig").Config;

pub const DB = struct {
    conn: myzql.conn.Conn,

    pub fn init(allocator: std.mem.Allocator, conf: Config) !DB {
        const conn = try myzql.conn.Conn.init(allocator, .{
            .host = conf.db_host,
            .port = conf.db_port,
            .user = conf.db_user,
            .password = conf.db_password,
            .database = conf.db_name,
        });
        return DB{ .conn = conn };
    }

    pub fn deinit(self: *DB) void {
        self.conn.deinit();
    }

    pub fn findPreferredRoutes(self: *DB, allocator: std.mem.Allocator, origin: []const u8, dest: []const u8) !std.ArrayList(models.RouteResult) {
        // 1. Prepare
        const query = "SELECT route_string FROM nfdc_preferred_routes WHERE origin = ? AND destination = ?";
        const prep_res = try self.conn.prepare(allocator, query);
        defer prep_res.deinit(allocator);
        
        const stmt = try prep_res.expect(.stmt);

        // 2. Execute
        const res = try self.conn.execute(&stmt, .{ origin, dest });
        const rows_result = try res.expect(.rows);
        
        // 3. Iterate
        var results = std.ArrayList(models.RouteResult).init(allocator);
        var iter = rows_result.iter();

        while (try iter.next()) |row| {
            // Scan into temp struct to handle binary data safely
            const RowData = struct { route_string: []u8 };
            var row_data: RowData = undefined;
            try row.scan(&row_data);

            try results.append(.{
                .Origin = origin,
                .Destination = dest,
                .RouteString = try allocator.dupe(u8, row_data.route_string),
                .Source = "Preferred",
            });
        }
        return results;
    }
};