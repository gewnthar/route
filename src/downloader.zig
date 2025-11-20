const std = @import("std");

pub fn refreshData(allocator: std.mem.Allocator) ![]u8 {
    try ensureDataDir();

    const PREF_URL = "https://www.fly.faa.gov/rmt/data_file/prefroutes_db.csv";
    const CDR_URL  = "https://www.fly.faa.gov/rmt/data_file/codedswap_db.csv";

    const pref_path = "data/prefroutes_db.csv";
    const cdr_path  = "data/codedswap_db.csv";

    const pref_bytes = try downloadToFile(allocator, PREF_URL, pref_path);
    const cdr_bytes  = try downloadToFile(allocator, CDR_URL,  cdr_path);

    return try std.fmt.allocPrint(allocator,
        "{{\"prefroutes_bytes\":{d},\"cdr_bytes\":{d}}}",
        .{ pref_bytes, cdr_bytes }
    );
}

fn ensureDataDir() !void {
    std.fs.cwd().makeDir("data") catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };
}

pub fn downloadToFile(allocator: std.mem.Allocator, url: []const u8, out_path: []const u8) !usize {
    // Uses system curl to avoid Zig http dependency issues
    const argv = [_][]const u8{
        "curl", "-fLsS", "-o", out_path, url,
    };

    var child = std.process.Child.init(&argv, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    const term = try child.spawnAndWait();
    switch (term) {
        .Exited => |code| if (code != 0) return error.UnexpectedStatus,
        else => return error.UnexpectedStatus,
    }

    const file = try std.fs.cwd().openFile(out_path, .{});
    defer file.close();
    const st = try file.stat();
    return @as(usize, @intCast(st.size));
}