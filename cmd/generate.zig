const std = @import("std");

const args = @import("args");

const Self = @This();

cmd: args.Cmd() = .{ .name = "generate" },

transport: args.Flag(?[]const u8) = .{ .long = "transport" },
port: args.Flag(?u16) = .{ .long = "port", .short = 'p' },

pub fn Execute(_: *Self) !void {
    std.debug.print("executing generate\n", .{});
}
