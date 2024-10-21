const std = @import("std");

// const Options = @import("../../build.zig").Options;

const demo_name = "minimal_zgui_glfw_gl";
const content_dir = demo_name ++ "_content/";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // command line arguments parser
    const args = b.dependency("args", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("args", args.module("args"));

    const serial = b.dependency("serial", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("serial", serial.module("serial"));
    // exe.linkLibrary(serial.artifact("serial"));

    // @import("system_sdk").addLibraryPathsTo(exe);

    // const zglfw = b.dependency("zglfw", .{
    //     // .target = options.target,
    // });
    // exe.root_module.addImport("zglfw", zglfw.module("root"));
    // exe.linkLibrary(zglfw.artifact("glfw"));
    //
    // const zopengl = b.dependency("zopengl", .{
    //     // .target = options.target,
    // });
    // exe.root_module.addImport("zopengl", zopengl.module("root"));
    //
    // const zgui = b.dependency("zgui", .{
    //     // .target = options.target,
    //     .backend = .glfw_opengl3,
    // });
    // exe.root_module.addImport("zgui", zgui.module("root"));
    // exe.linkLibrary(zgui.artifact("imgui"));
    //
    // // const content_path = b.pathJoin(&.{ cwd_path, content_dir });
    // const install_content_step = b.addInstallDirectory(.{
    //     .source_dir = b.path("./content/"),
    //     .install_dir = .{ .custom = "" },
    //     .install_subdir = b.pathJoin(&.{ "bin", "./content/" }),
    // });
    // exe.step.dependOn(&install_content_step.step);

    b.installArtifact(exe);
}
