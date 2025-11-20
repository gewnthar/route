const std = @import("std");

// --- API Models (JSON) ---

pub const RouteRequest = struct {
    origin: []const u8,
    destination: []const u8,
};

pub const RouteResult = struct {
    Origin: []const u8,
    Destination: []const u8,
    RouteString: []const u8,
    Source: []const u8,
    Type: []const u8 = "",
    Altitude: []const u8 = "",
    Aircraft: []const u8 = "",
};

// --- CSV Data Models ---

pub const PreferredRoute = struct {
    origin: []const u8,
    route_string: []const u8,
    destination: []const u8,
    hours1: []const u8,
    hours2: []const u8,
    hours3: []const u8,
    type_code: []const u8,
    area: []const u8,
    altitude: []const u8,
    aircraft: []const u8,
    direction: []const u8,
    seq: u32,
    dcntr: []const u8,
    acntr: []const u8,

    pub fn parse(line: []const u8) !PreferredRoute {
        var it = std.mem.splitScalar(u8, line, ',');
        return PreferredRoute{
            .origin = trim(it.next() orelse ""),
            .route_string = trim(it.next() orelse ""),
            .destination = trim(it.next() orelse ""),
            .hours1 = trim(it.next() orelse ""),
            .hours2 = trim(it.next() orelse ""),
            .hours3 = trim(it.next() orelse ""),
            .type_code = trim(it.next() orelse ""),
            .area = trim(it.next() orelse ""),
            .altitude = trim(it.next() orelse ""),
            .aircraft = trim(it.next() orelse ""),
            .direction = trim(it.next() orelse ""),
            .seq = std.fmt.parseInt(u32, trim(it.next() orelse "0"), 10) catch 0,
            .dcntr = trim(it.next() orelse ""),
            .acntr = trim(it.next() orelse ""),
        };
    }
};

pub const CdrRoute = struct {
    rcode: []const u8,
    origin: []const u8,
    destination: []const u8,
    dep_fix: []const u8,
    route_string: []const u8,
    dcntr: []const u8,
    acntr: []const u8,
    tcntrs: []const u8,
    coord_req: []const u8,
    play: []const u8,
    nav_eqp: []const u8,

    pub fn parse(line: []const u8) !CdrRoute {
        var it = std.mem.splitScalar(u8, line, ',');
        return CdrRoute{
            .rcode = trim(it.next() orelse ""),
            .origin = trim(it.next() orelse ""),
            .destination = trim(it.next() orelse ""),
            .dep_fix = trim(it.next() orelse ""),
            .route_string = trim(it.next() orelse ""),
            .dcntr = trim(it.next() orelse ""),
            .acntr = trim(it.next() orelse ""),
            .tcntrs = trim(it.next() orelse ""),
            .coord_req = trim(it.next() orelse ""),
            .play = trim(it.next() orelse ""),
            .nav_eqp = trim(it.next() orelse ""),
        };
    }
};

fn trim(input: []const u8) []const u8 {
    return std.mem.trim(u8, input, " \t\r\n\"");
}