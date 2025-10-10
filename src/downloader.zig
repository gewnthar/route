// SPDX-License-Identifier: MIT
// File: src/downloader.zig
//
// FAA Route Finder — FAA CSV downloader.
//
// - Creates ./data if missing.
// - Streams two public CSVs to disk:
//     prefroutes_db.csv  (NFDC Preferred Routes)
//     codedswap_db.csv   (CDM Operational CDRs)
// - Uses std.http.Client.fetch (Zig 0.15.1) and streams to file.
// - Returns a small JSON string with byte counts.
//
// Files:
//   data/prefroutes_db.csv
//   data/codedswap_db.csv
//
// Errors:
//   error.UnexpectedStatus if HTTP status != 200 OK
//
// See also:
//   src/handlers.zig (handleRefresh)


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
        "{{\"prefroutes_bytes\":{d},\"cdr_bytes\":{d}}}\n",
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
    var argv = [_][]const u8{
        "curl", "-fLsS", "-o", out_path, url,
    };

    var child = std.process.Child.init(&argv, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    // Ensure ./data exists (caller already does ensureDataDir(), but harmless)
    std.fs.cwd().makeDir(std.fs.path.dirname(out_path) orelse ".") catch {};

    const term = try child.spawnAndWait();
    switch (term) {
        .Exited => |code| if (code != 0) return error.UnexpectedStatus,
        else => return error.UnexpectedStatus,
    }

    // Return the number of bytes written
    const st = try std.fs.cwd().statFile(out_path);
    return @as(usize, @intCast(st.size));
}