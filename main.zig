const std = @import("std");

const clap = @import("clap");
const serial = @import("serial");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // First we specify what parameters our program can take.
    // We can use `parseParamsComptime` to parse a string into an array of `Param(Help)`
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-n, --number <usize>   An option parameter, which takes a value.
        \\-s, --string <str>...  An option parameter which can be specified multiple times.
        \\<str>...
        \\
    );

    // Initialize our diagnostics, which can be used for reporting useful errors.
    // This is optional. You can also pass `.{}` to `clap.parse` if you don't
    // care about the extra information `Diagnostics` provides.
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = gpa.allocator(),
    }) catch |err| {
        // Report useful error and exit
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0)
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{ .indent = 0, .description_indent = 4 });
    if (res.args.number) |n|
        std.debug.print("--number = {}\n", .{n});
    for (res.args.string) |s|
        std.debug.print("--string = {s}\n", .{s});
    for (res.positionals) |pos|
        std.debug.print("{s}\n", .{pos});

    try m();
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
