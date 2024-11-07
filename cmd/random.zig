const std = @import("std");

const args = @import("args");
const xev = @import("xev");

const Self = @This();

cmd: args.Cmd() = .{ .name = "random" },

pub fn Execute(_: *Self) !void {
    std.debug.print("rangom\n", .{});

    var loop = try xev.Loop.init(.{});
    defer loop.deinit();

    const w = try xev.Timer.init();
    defer w.deinit();

    // 5s timer
    var c: xev.Completion = undefined;
    w.run(&loop, &c, 5000, void, null, &timerCallback);

    try loop.run(.until_done);

    std.debug.print("done rangom\n", .{});
}

fn timerCallback(
    userdata: ?*void,
    loop: *xev.Loop,
    c: *xev.Completion,
    result: xev.Timer.RunError!void,
) xev.CallbackAction {
    _ = userdata;
    _ = loop;
    _ = c;
    _ = result catch unreachable;
    return .disarm;
}
