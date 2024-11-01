const std = @import("std");
const net = std.net;

const args = @import("args");

const Self = @This();

cmd: args.Cmd() = .{ .name = "generate" },

transport: args.Flag(?[]const u8) = .{ .long = "transport", .short = 't' },
port: args.Flag(u16) = .{ .long = "port", .short = 'p', .value = 8080 },

pub fn Execute(self: *Self) !void {
    std.debug.print("executing generate\n", .{});
    if (self.transport.called and std.mem.eql(u8, "tcp", self.transport.value.?)) {
        std.debug.print("starting generate with tcp transport\n", .{});

        // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        // defer _ = gpa.deinit();
        // const allocator = gpa.allocator();

        const address = try net.Address.parseIp4("127.0.0.1", self.port.value);
        const stream = try net.tcpConnectToAddress(address);
        defer stream.close();

        const msg = "hello!";
        const n = try stream.write(msg);
        std.debug.print("sent {} bytes\n", .{n});
    }
}
