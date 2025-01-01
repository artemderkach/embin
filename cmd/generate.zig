const std = @import("std");
const net = std.net;

const args = @import("args");
const xev = @import("xev");

const Allocator = std.mem.Allocator;
const Instant = std.time.Instant;
const assert = std.debug.assert;

const Self = @This();

cmd: args.Cmd() = .{ .name = "generate" },

transport: args.Flag(?[]const u8) = .{ .long = "transport", .short = 't' },
port: args.Flag(u16) = .{ .long = "port", .short = 'p', .value = 8080 },

pub fn Execute(_: *Self) !void {
    var loop = try xev.Loop.init(.{});
    defer loop.deinit();

    // fire off event then start timer
    // in case you want do waiting before event do:
    // loop.timer(&c, wait, null, callback);
    var c: xev.Completion = undefined;
    _ = timerCallback(null, &loop, &c, .{ .noop = undefined });

    // Tick
    try loop.run(.until_done);
}

fn timerCallback(_: ?*anyopaque, l: *xev.Loop, c: *xev.Completion, _: xev.Result) xev.CallbackAction {
    l.timer(c, 1_000, null, timerCallback);
    std.debug.print("hhh\n", .{});

    return .disarm;
}
