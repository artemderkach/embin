const std = @import("std");

const serial = @import("serial");

pub fn main() !void {
    const commandSerial = "serial";
    if (std.os.argv.len <= 1) {
        return;
    }

    std.debug.print("There are {d} args:\n", .{std.os.argv.len});
    for(std.os.argv) |arg| {
        std.debug.print("  {s}, {}, {any}\n", .{arg, @TypeOf(arg), std.mem.span(arg)});
    }

    const inputCommand = std.mem.span(std.os.argv[1]);
    if (std.mem.eql(u8, inputCommand, commandSerial)) {
        std.debug.print("applying serial command\n", .{});
        try readSerial();
    }
}

fn readSerial() !void {
    const port_name = "/dev/ttys004";

    var s = std.fs.cwd().openFile(port_name, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Invalid config: the serial port '{s}' does not exist.\n", .{port_name});
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

