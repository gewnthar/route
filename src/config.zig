const std = @import("std");

pub const Config = struct {
    server_port: u16,
    db_host: []const u8,
    db_port: u16,
    db_user: []const u8,
    db_password: []const u8,
    db_name: []const u8,
};

pub fn load(allocator: std.mem.Allocator, path: []const u8) !Config {
    // Open the file
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    // Set defaults
    var config = Config{
        .server_port = 8080,
        .db_host = "127.0.0.1",
        .db_port = 3306,
        .db_user = "root",
        .db_password = "",
        .db_name = "faa_dst_db",
    };

    // Buffer for reading lines
    var buf_reader = std.io.bufferedReader(file.reader());
    var line_buf: [1024]u8 = undefined;

    // Read line-by-line
    while (try buf_reader.reader().readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        // Skip comments or empty lines
        if (line.len == 0 or line[0] == '#') continue;
        
        // Split by '='
        if (std.mem.indexOfScalar(u8, line, '=')) |sep_index| {
            const key = std.mem.trim(u8, line[0..sep_index], " \r\n\t");
            // Trim quotes from value if present
            const value = std.mem.trim(u8, line[sep_index + 1 ..], " \r\n\t\"");

            // Map keys to struct fields
            if (std.mem.eql(u8, key, "SERVER_PORT")) config.server_port = try std.fmt.parseInt(u16, value, 10);
            if (std.mem.eql(u8, key, "DB_HOST")) config.db_host = try allocator.dupe(u8, value);
            if (std.mem.eql(u8, key, "DB_PORT")) config.db_port = try std.fmt.parseInt(u16, value, 10);
            if (std.mem.eql(u8, key, "DB_USER")) config.db_user = try allocator.dupe(u8, value);
            if (std.mem.eql(u8, key, "DB_PASSWORD")) config.db_password = try allocator.dupe(u8, value);
            if (std.mem.eql(u8, key, "DB_NAME")) config.db_name = try allocator.dupe(u8, value);
        }
    }
    return config;
}