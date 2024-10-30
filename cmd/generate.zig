const std = @import("std");

const args = @import("args");

const Generate = struct {
    cmd: args.Cmd() = .{ .name = "generate" },

    transport: args.Flag(?[]const u8) = .{ .long = "transport" },
    port: args.Flag(?u16) = .{ .long = "port", .short = 'p' },

    pub fn Execute(_: *Generate) !void {}
};
