//! start command begins main process for application
//! it will create 2 subprocesses
//! - process that draws
//! - process that listens to incoming data (tcp, http, serial)
//! this 2 subprocesses will communicate via queue
const std = @import("std");
const net = std.net;

const args = @import("args");
const xev = @import("xev");

const draw = @import("../core/draw.zig");
const queue = @import("../core/queue.zig");

const ThreadPool = xev.ThreadPool;

const Self = @This();

cmd: args.Cmd() = .{ .name = "start" },

port: args.Flag(u16) = .{ .long = "port", .short = 'p', .value = 8080 },
transport: args.Flag(?[]const u8) = .{ .long = "transport", .short = 't' },

pub fn Execute(_: *Self) !void {
    // const handler = try std.Thread.spawn(.{}, run, .{});
    // handler.join();
    //

    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();

    const al = std.ArrayList([]u8).init(gpa);

    var q = queue.Queue.init(al);
    defer q.deinit();

    var handler = try std.Thread.spawn(.{}, run, .{&q});
    defer handler.join();

    var tp = ThreadPool.init(.{});
    defer tp.deinit();

    // var task = ThreadPool.Task{
    //     .callback = callback,
    // };
    // var task2 = ThreadPool.Task{
    //     .callback = callback,
    // };

    // const batch = ThreadPool.Batch.from(&task);
    // const batch2 = ThreadPool.Batch.from(&task2);

    // tp.schedule(batch1);
    // tp.schedule(batch2);

    try draw.run(&q);
    std.debug.print("end\n", .{});
}

fn run(q: *queue.Queue) !void {
    var items = [_]u8{ 1, 2, 3 };
    // var known_at_runtime_zero: usize = 0;
    // _ = &known_at_runtime_zero;
    // var slice = items[known_at_runtime_zero..items.len];
    // _ = &slice;
    //
    // var i: []u8 = slice;
    // _ = &i;

    // var slice = items[0..items.len];
    // _ = &slice;

    const ff: []const []u8 = &.{&items};

    while (true) {
        try q.addItems(ff);
        std.time.sleep(std.time.ms_per_s * 100);
    }
}

const zgui = @import("zgui");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");

const window_title = "zig-gamedev: minimal zgpu glfw opengl3";
