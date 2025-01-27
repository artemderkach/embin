const std = @import("std");
const net = std.net;

const xev = @import("xev");
const args = @import("args");

const TCP = @import("../core/tcp.zig").TCP;

const Self = @This();

cmd: args.Cmd() = .{ .name = "tcp" },

pub fn Execute(_: *Self) !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();

    var loop = try xev.Loop.init(.{});
    defer loop.deinit();

    const addr = try net.Address.parseIp("127.0.0.1", 8080);
    var tcp = TCP{
        .loop = &loop,
        .address = addr,
        .allocator = gpa,
    };
    _ = &tcp;

    std.debug.print("hello {any}\n", .{"123"});
    try std.testing.expect(true);
    // try std.testing.expect(false);
    //
    //

    std.debug.print("started loop {any}\n", .{"123"});

    try tcp.listen();

    try loop.run(.until_done);
}
