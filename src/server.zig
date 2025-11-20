const std = @import("std");
const posix = std.posix;

// We use the Context to keep the API consistent, even if we don't use it fully yet
const handlers = @import("handlers.zig");

pub fn start(allocator: std.mem.Allocator, port: u16, _: handlers.Context) !void {
    _ = allocator; // Raw posix doesn't need the allocator for this simple loop

    // 1. Create a TCP Socket
    const sockfd = try posix.socket(posix.AF.INET, posix.SOCK.STREAM, posix.IPPROTO.TCP);
    defer posix.close(sockfd);

    // 2. Enable Address Reuse (so you can restart quickly)
    const yes: i32 = 1;
    try posix.setsockopt(sockfd, posix.SOL.SOCKET, posix.SO.REUSEADDR, std.mem.asBytes(&yes));

    // 3. Bind to 127.0.0.1 (Localhost)
    // We manually construct the address struct because std.net is missing
    const addr = posix.sockaddr.in{
        .family = posix.AF.INET,
        .port = std.mem.nativeToBig(u16, port),
        .addr = std.mem.nativeToBig(u32, 0x7F000001), // 127.0.0.1
        .zero = .{0} ** 8,
    };
    try posix.bind(sockfd, @ptrCast(&addr), @sizeOf(@TypeOf(addr)));

    // 4. Listen
    try posix.listen(sockfd, 128);
    std.log.info("Server listening on 127.0.0.1:{d} (Raw POSIX Mode)", .{port});

    // 5. Accept Loop
    while (true) {
        var client_addr: posix.sockaddr.in = undefined;
        var client_addr_len: posix.socklen_t = @sizeOf(posix.sockaddr.in);
        
        const client_fd = try posix.accept(sockfd, @ptrCast(&client_addr), &client_addr_len);
        
        // Spawn a thread or handle linearly. For parking mode, linear is fine.
        handleRawConnection(client_fd) catch |err| {
            std.log.err("Connection error: {}", .{err});
        };
    }
}

fn handleRawConnection(fd: posix.socket_t) !void {
    defer posix.close(fd);

    // 1. Read (Drain) the request
    // We don't parse it in parking mode, just consume it so the client is happy
    var buf: [4096]u8 = undefined;
    _ = try posix.read(fd, &buf);

    // 2. Write a raw HTTP response
    // This mimics a valid API response so your frontend works
    const response = 
        "HTTP/1.1 200 OK\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Connection: close\r\n" ++
        "\r\n" ++
        "{\"status\": \"parked\", \"message\": \"Waiting for Zig 0.16 stability\"}";

    _ = try posix.write(fd, response);
}