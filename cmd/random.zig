const std = @import("std");

const args = @import("args");
const xev = @import("xev");

const Self = @This();

cmd: args.Cmd() = .{ .name = "random" },

pub fn Execute(_: *Self) !void {
    var loop = try xev.Loop.init(.{});
    defer loop.deinit();

    const addr = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, 8080);
    var tcp = try xev.TCP.init(addr);
    try tcp.bind(addr);
    try tcp.listen(100);

    var c: xev.Completion = undefined;
    tcp.accept(&loop, &c, void, null, &callback);

    std.debug.print("rangom\n", .{});
    try loop.run(.until_done);

    std.debug.print("done rangom\n", .{});
}

fn callback(
    userdata: ?*void,
    loop: *xev.Loop,
    c: *xev.Completion,
    result: xev.AcceptError!xev.TCP,
) xev.CallbackAction {
    std.debug.print("callback\n", .{});
    _ = userdata;
    _ = loop;
    _ = c;
    _ = result catch unreachable;
    return .rearm;
}
