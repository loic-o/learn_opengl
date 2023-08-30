const std = @import("std");

const zglfw = @import("libs/zglfw/build.zig");
const zopengl = @import("libs/zopengl/build.zig");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const exercises = [_]Exercise{
        .{ .name = "hello_window", .src = "src/1_1_hello_window.zig" },
    };

    for (exercises) |exercise| {
        build_exercise(b, exercise);
    }
}

const Exercise = struct {
    name: []const u8,
    src: []const u8,
};

fn build_exercise(b: *std.Build, exercise: Exercise) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = exercise.name,
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = exercise.src },
        .target = target,
        .optimize = optimize,
    });

    const zglfw_pkg = zglfw.package(b, target, optimize, .{});
    const zopengl_pkg = zopengl.package(b, target, optimize, .{});

    zglfw_pkg.link(exe);
    zopengl_pkg.link(exe);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step(exercise.name, "Run this example");
    run_step.dependOn(&run_cmd.step);
}
