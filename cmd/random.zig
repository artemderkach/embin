const std = @import("std");

const args = @import("args");
const xev = @import("xev");

const Self = @This();

cmd: args.Cmd() = .{ .name = "random" },

var tcp: xev.TCP = undefined;

pub fn Execute(_: *Self) !void {
    var loop = try xev.Loop.init(.{});
    defer loop.deinit();

    const addr = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, 8080);
    tcp = try xev.TCP.init(addr);
    try tcp.bind(addr);
    try tcp.listen(100);

    var c: xev.Completion = undefined;
    tcp.accept(&loop, &c, void, null, &callback);

    std.debug.print("rangom\n", .{});
    try loop.run(.until_done);

    std.debug.print("done rangom\n", .{});
}

fn callback(userdata: ?*void, loop: *xev.Loop, c: *xev.Completion, result: xev.AcceptError!xev.TCP) xev.CallbackAction {
    std.debug.print("callback\n", .{});
    _ = userdata;
    _ = c;

    if (result) |_| {} else |err| {
        std.debug.print("read err: {}\n", .{err});
        return .disarm;
    }

    var rc: xev.Completion = undefined;
    const buf: xev.ReadBuffer = .{ .array = undefined };

    tcp.read(loop, &rc, buf, void, null, &readCB);
    return .rearm;
}

fn readCB(ud: ?*void, l: *xev.Loop, c: *xev.Completion, s: xev.TCP, b: xev.ReadBuffer, r: xev.ReadError!usize) xev.CallbackAction {
    std.debug.print("read\n", .{});
    _ = ud;
    _ = l;
    _ = c;
    _ = s;
    _ = b;

    if (r) |size| {
        _ = size;
    } else |err| {
        std.debug.print("read err: {}\n", .{err});
        return .disarm;
    }

    return .rearm;
}
