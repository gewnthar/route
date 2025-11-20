pub const RouteRequest = struct {
    origin: []const u8,
    destination: []const u8,
};

pub const RouteResult = struct {
    Origin: []const u8,
    Destination: []const u8,
    RouteString: []const u8,
    Source: []const u8,
};