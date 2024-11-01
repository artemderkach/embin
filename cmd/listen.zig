const std = @import("std");
const net = std.net;

const args = @import("args");

const Self = @This();

cmd: args.Cmd() = .{ .name = "listen" },

port: args.Flag(u16) = .{ .long = "port", .short = 'p', .value = 8080 },
transport: args.Flag(?[]const u8) = .{ .long = "transport", .short = 't' },

pub fn Execute(self: *Self) !void {
    std.debug.print("listening\n", .{});

    if (self.transport.called and std.mem.eql(u8, "tcp", self.transport.value.?)) {
        std.debug.print("starting listener with tcp transport\n", .{});

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();

        const address = try net.Ip4Address.parse("127.0.0.1", self.port.value);
        const localhost = net.Address{ .in = address };
        var server = try localhost.listen(.{
            .reuse_port = true,
        });
        defer server.deinit();

        const addr = server.listen_address;
        std.debug.print("Listening on {}, access this port to end the program\n", .{addr.getPort()});

        while (true) {
            var client = try server.accept();
            defer client.stream.close();

            std.debug.print("Connection received! {} is sending data.\n", .{client.address});

            while (true) {
                var message = try allocator.alloc(u8, 1024);
                defer allocator.free(message);

                const n = try client.stream.read(message);
                if (n == 0) break;

                std.debug.print("{} says {s}\n", .{ client.address, message[0..n] });
            }
        }
    }
}
