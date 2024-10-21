const std = @import("std");

const clap = @import("clap");
const serial = @import("serial");
const args = @import("args");

var config = struct {
    serial: struct {
        cmd: args.Cmd() = .{ .name = "serial" },
        listen: struct {
            cmd: args.Cmd() = .{ .name = "listen" },
        } = .{},
        generate: struct {
            cmd: args.Cmd() = .{ .name = "listen" },
        } = .{},
        port: args.Flag(?[]const u8) = .{},
    } = .{},
}{};

pub fn main() !void {
    try args.parse(&config);
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
