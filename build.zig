const std = @import("std");
const protobuf = @import("protobuf");

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

    const protobuf_dep = b.dependency("protobuf", .{
        .target = target,
        .optimize = optimize,
    });

    // and lastly use the dependency as a module
    exe.root_module.addImport("protobuf", protobuf_dep.module("protobuf"));
    // @import("system_sdk").addLibraryPathsTo(exe);
    //
    const gen_proto = b.step("gen-proto", "generates zig files from protocol buffer definitions");
    const protoc_step = protobuf.RunProtocStep.create(b, protobuf_dep.builder, target, .{
        // out directory for the generated zig files
        .destination_directory = b.path("./protobuf/"),
        .source_files = &.{
            "./protobuf/simple.proto",
        },
        .include_directories = &.{},
    });
    gen_proto.dependOn(&protoc_step.step);

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
