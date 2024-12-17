const std = @import("std");
const net = std.net;

const args = @import("args");

const zgui = @import("zgui");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");

const window_title = "zig-gamedev: minimal zgpu glfw opengl3";

const Self = @This();

cmd: args.Cmd() = .{ .name = "listen" },

port: args.Flag(u16) = .{ .long = "port", .short = 'p', .value = 8080 },
transport: args.Flag(?[]const u8) = .{ .long = "transport", .short = 't' },

pub fn Execute(_: *Self) !void {
    std.debug.print("listening\n", .{});

    try glfw.init();
    defer glfw.terminate();

    // Change current working directory to where the executable is located.
    {
        var buffer: [1024]u8 = undefined;
        const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
        std.posix.chdir(path) catch {};
    }

    const gl_major = 4;
    const gl_minor = 0;
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);

    const window = try glfw.Window.create(800, 500, window_title, null);
    defer window.destroy();
    // window.setSizeLimits(400, 400, -1, -1);

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    const gl = zopengl.bindings;

    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    zgui.init(gpa);
    defer zgui.deinit();

    const scale_factor = scale_factor: {
        const scale = window.getContentScale();
        break :scale_factor @max(scale[0], scale[1]);
    };
    _ = zgui.io.addFontFromFile(
        "./content/Roboto-Medium.ttf",
        std.math.floor(16.0 * scale_factor),
    );

    zgui.getStyle().scaleAllSizes(scale_factor);

    zgui.backend.init(window);
    defer zgui.backend.deinit();

    zgui.plot.init();
    defer zgui.plot.deinit();

    var list = std.ArrayList(i32).init(gpa);
    try list.append(0);
    try list.append(1);
    try list.append(3);
    try list.append(3);
    defer list.deinit();

    var list2 = std.ArrayList(f32).init(gpa);
    try list2.append(1.2);
    try list2.append(1.6);
    try list2.append(3.3);
    try list2.append(4.0);
    defer list2.deinit();

    std.debug.print("{any}", .{list.items});
    std.debug.print("{any}", .{list2.items});
    // list.

    const startTime: i64 = std.time.milliTimestamp();
    var fromStart: i64 = 0;
    var prevTime: i64 = std.time.milliTimestamp();

    var samplesX: [100]f64 = undefined;
    var samples: [100]f64 = undefined;

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        fromStart = std.time.milliTimestamp() - startTime;

        std.debug.print("{any}\n", .{prevTime - std.time.milliTimestamp()});
        prevTime = std.time.milliTimestamp();

        if (isNextFrame()) {
            for (samplesX, 0..) |_, i| {
                samplesX[i] = @as(f64, @floatFromInt(i));
            }

            for (samples, 0..) |_, i| {
                samples[i] = @sin(@as(f64, @floatFromInt(i)) * @as(f64, 0.2) + @as(f64, @floatFromInt(fromStart)) * @as(f64, 1.5));
            }
        }

        const first = list.pop();
        try list.insert(0, first);

        const first2 = list2.pop();
        try list2.insert(0, first2);

        // std.debug.print("{any}", .{list.items});
        // std.debug.print("{any}\n", .{list2.items});
        // std.debug.print("{any}\n", .{isNextFrame()});

        //
        // std.debug.print("loop...\n", .{});
        // std.time.sleep(std.time.ns_per_s);

        glfw.pollEvents();

        gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0, 0, 0, 1.0 });

        const fb_size = window.getFramebufferSize();

        zgui.backend.newFrame(@intCast(fb_size[0]), @intCast(fb_size[1]));

        // Set the starting window position and size to custom values
        // zgui.setNextWindowPos(.{ .x = 20.0, .y = 20.0, .cond = .first_use_ever });
        // zgui.setNextWindowSize(.{ .w = -1.0, .h = -1.0, .cond = .first_use_ever });
        //

        if (zgui.begin("My window", .{})) {
            // if (zgui.button("Press me!", .{ .w = 200.0 })) {
            //     std.debug.print("Button pressed\n", .{});
            // }
        }

        if (zgui.plot.beginPlot("Line Plot", .{ .h = -1.0 })) {
            zgui.plot.setupAxis(.x1, .{ .label = "xaxis" });
            zgui.plot.setupAxisLimits(.x1, .{ .min = 0, .max = 5 });
            zgui.plot.setupLegend(.{ .south = true, .west = true }, .{});
            zgui.plot.setupFinish();

            // zgui.plot.plotLineValues("y data", i32, .{
            //     .v = list.items,
            //     // .v = &.{1, 2, 3, 4}
            // });
            zgui.plot.plotLine("xy data", f64, .{
                .xv = &samplesX,
                .yv = &samples,
            });

            // .{
            // .xv = &.{ 0.1, 0.2, 0.5, 2.5 },
            // .yv = &.{ 0.1, 0.3, 0.5, 0.9 },
            // .xv = list2.items,
            // .yv = list2.items,
            // }
            // );
            // zgui.plot.plotScatter("test scatter", f32, .{
            //     // .xv = &.{1.5, 1.9, 2.2},
            //     // .yv = &.{1.5, 1.9, 2.2},
            //     .xv = try list2.toOwnedSlice(),
            //     .yv = try list2.toOwnedSlice(),
            // });
            zgui.plot.endPlot();
        }

        zgui.end();

        zgui.backend.draw();

        window.swapBuffers();
    }
}

var time: i64 = undefined;
const frameDuration: i64 = 1000; // > 60 fps

fn isNextFrame() bool {
    if (time == undefined) {
        time = std.time.milliTimestamp();
    }
    const currTime = std.time.milliTimestamp();
    const diff = currTime - time;
    const remaider = @rem(diff, frameDuration);

    if (diff > frameDuration) {
        time = currTime - remaider;
        return true;
    }

    return false;
}

var nextCounter: f64 = undefined;
fn next() f64 {
    if (nextCounter == undefined) {
        nextCounter = @as(f64, @floatFromInt(std.time.milliTimestamp()));
    }
    nextCounter += 1.0;

    return nextCounter;
}
