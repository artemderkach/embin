const std = @import("std");
const net = std.net;

const clap = @import("clap");
const serial = @import("serial");
const args = @import("args");

var config = struct {
    listen: struct {
        cmd: args.Cmd() = .{ .name = "listen" },
    } = .{},
    generate: struct {
        cmd: args.Cmd() = .{ .name = "generate" },
    } = .{},

    transport: args.Flag(?[]const u8) = .{ .long = "transport" },
    port: args.Flag(?u16) = .{ .long = "port", .short = 'p' },

    serial: struct {
        cmd: args.Cmd() = .{ .name = "serial" },
        listen: struct {
            cmd: args.Cmd() = .{ .name = "listen" },
        } = .{},
        generate: struct {
            cmd: args.Cmd() = .{ .name = "listen" },
        } = .{},
        port: args.Arg(?[]const u8) = .{},
    } = .{},
}{};

pub fn main() !void {
    try args.parse(&config);

    if (config.serial.listen.cmd.called) {
        std.debug.print("serial listen\n", .{});
        std.debug.print("port: {s}\n", .{config.serial.port.value.?});

        var s = std.fs.cwd().openFile(config.serial.port.value.?, .{ .mode = .read_write }) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("Invalid config: the serial port '{s}' does not exist.\n", .{config.serial.port.value.?});
                return;
            },
            else => unreachable,
        };
        defer s.close();

        try serial.configureSerialPort(s, serial.SerialConfig{
            .baud_rate = 115200,
            .word_size = .eight,
            .parity = .none,
            .stop_bits = .one,
            .handshake = .none,
        });

        // try s.writer().writeAll("Hello, World!\r\n");

        while (true) {
            std.debug.print("new loop\n", .{});
            const b = try s.reader().readByte();
            std.debug.print("{s}", .{[_]u8{b}});
        }
    }

    if (config.serial.generate.cmd.called) {
        std.debug.print("serial generate\n", .{});
        var s = std.fs.cwd().openFile(config.serial.port.value.?, .{ .mode = .read_write }) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("Invalid config: the serial port '{s}' does not exist.\n", .{config.serial.port.value.?});
                return;
            },
            else => unreachable,
        };
        defer s.close();
        // try serial.configureSerialPort(s, serial.SerialConfig{
        //     .baud_rate = 115200,
        //     .word_size = .eight,
        //     .parity = .none,
        //     .stop_bits = .one,
        //     .handshake = .none,
        // });
        try s.writeAll("Hello, World!\r\n");
    }

    if (config.listen.cmd.called and std.mem.eql(u8, config.transport.value.?, "tcp")) {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();

        const loopback = try net.Ip4Address.parse("127.0.0.1", 0);
        const localhost = net.Address{ .in = loopback };
        var server = try localhost.listen(.{
            .reuse_port = true,
        });
        defer server.deinit();

        const addr = server.listen_address;
        std.debug.print("Listening on {}, access this port to end the program\n", .{addr.getPort()});

        var client = try server.accept();
        defer client.stream.close();

        std.debug.print("Connection received! {} is sending data.\n", .{client.address});

        const message = try client.stream.reader().readAllAlloc(allocator, 1024);
        defer allocator.free(message);

        std.debug.print("{} says {s}\n", .{ client.address, message });
    }

    if (config.generate.cmd.called and std.mem.eql(u8, config.transport.value.?, "tcp")) {
        const peer = try net.Address.parseIp4("127.0.0.1", config.port.value.?);
        // Connect to peer
        const stream = try net.tcpConnectToAddress(peer);
        defer stream.close();
        std.debug.print("Connecting to {}\n", .{peer});

        // Sending data to peer
        const data = "hello zig";
        var writer = stream.writer();
        const size = try writer.write(data);
        std.debug.print("Sending '{s}' to peer, total written: {d} bytes\n", .{ data, size });
    }
}

pub fn m() !void {
    const commandSerial = "serial";

    if (std.os.argv.len <= 1) {
        return;
    }

    std.debug.print("There are {d} args:\n", .{std.os.argv.len});
    for (std.os.argv) |arg| {
        std.debug.print("  {s}, {}, {any}\n", .{ arg, @TypeOf(arg), std.mem.span(arg) });
    }

    const inputCommand = std.mem.span(std.os.argv[1]);

    var subcommand: []u8 = undefined;
    if (std.os.argv.len >= 3) {
        subcommand = std.mem.span(std.os.argv[2]);
    }

    if (std.mem.eql(u8, inputCommand, commandSerial)) {
        std.debug.print("applying serial command\n", .{});
        // var port: []u8 = undefined;
        try readSerial(subcommand);
    }
}

fn readSerial(port: []u8) !void {
    var s = std.fs.cwd().openFile(port, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Invalid config: the serial port '{s}' does not exist.\n", .{port});
            return;
        },
        else => unreachable,
    };
    defer s.close();

    try serial.configureSerialPort(s, serial.SerialConfig{
        .baud_rate = 115200,
        .word_size = .eight,
        .parity = .none,
        .stop_bits = .one,
        .handshake = .none,
    });

    try s.writer().writeAll("Hello, World!\r\n");

    while (true) {
        const b = try s.reader().readByte();
        std.debug.print("{s}", .{[_]u8{b}});
    }

    return;
}
