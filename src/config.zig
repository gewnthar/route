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

    // Fix: Read the whole file at once (Max 10KB)
    // This avoids the Zig 0.16 "writergate/readergate" stream API complexity
    const content = try file.readToEndAlloc(allocator, 1024 * 10);
    defer allocator.free(content);

    // Default values
    var config = Config{
        .server_port = 8080,
        .db_host = "127.0.0.1",
        .db_port = 3306,
        .db_user = "root",
        .db_password = "",
        .db_name = "faa_dst_db",
    };

    // Iterator over lines
    var lines = std.mem.splitScalar(u8, content, '\n');

    while (lines.next()) |line| {
        if (line.len == 0 or line[0] == '#') continue;
        
        if (std.mem.indexOfScalar(u8, line, '=')) |sep_index| {
            const key = std.mem.trim(u8, line[0..sep_index], " \r\n\t");
            const value = std.mem.trim(u8, line[sep_index + 1 ..], " \r\n\t\"");

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