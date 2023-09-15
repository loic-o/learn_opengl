const std = @import("std");

const zglfw = @import("libs/zglfw/build.zig");
const zopengl = @import("libs/zopengl/build.zig");
const zstbi = @import("libs/zstbi/build.zig");
const zmath = @import("libs/zmath/build.zig");
const zmesh = @import("libs/zmesh/build.zig");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const exercises = [_]Exercise{
        // getting started
        .{ .name = "hello_window", .src = "src/1_1_hello_window.zig" },
        .{ .name = "hello_triangle", .src = "src/1_2_hello_triangle.zig" },
        .{ .name = "shaders", .src = "src/1_3_shaders.zig" },
        .{ .name = "textures", .src = "src/1_4_textures.zig" },
        .{ .name = "transformations", .src = "src/1_5_transformations.zig" },
        .{ .name = "coordinate_systems", .src = "src/1_6_coordinate_systems.zig" },
        .{ .name = "camera", .src = "src/1_7_camera.zig" },
        // lighting
        .{ .name = "colors", .src = "src/2_1_colors.zig" },
        .{ .name = "basic_lighting", .src = "src/2_2_basic_lighting_a.zig" },
        .{ .name = "materials", .src = "src/2_3_materials.zig" },
        .{ .name = "lighting_maps", .src = "src/2_4_lighting_maps.zig" },
        .{ .name = "light_casters", .src = "src/2_5_light_casters.zig" },
        .{ .name = "multiple_lights", .src = "src/2_6_multiple_lights.zig" },
        // advanced opengl
        .{ .name = "depth_testing", .src = "src/4_1_depth_testing.zig" },
        .{ .name = "face_culling", .src = "src/4_4_face_culling.zig" },
        // loic - gltf
        .{ .name = "lpo_01", .src = "src/lpo_01_gltf.zig" },
    };

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const zglfw_pkg = zglfw.package(b, target, optimize, .{});
    const zopengl_pkg = zopengl.package(b, target, optimize, .{});
    const zstbi_pkg = zstbi.package(b, target, optimize, .{});
    const zmath_pkg = zmath.package(b, target, optimize, .{
        .options = .{ .enable_cross_platform_determinism = true },
    });
    const zmesh_pkg = zmesh.package(b, target, optimize, .{});

    var exe: *std.Build.Step.Compile = undefined;
    for (exercises) |exercise| {
        exe = build_exercise(b, exercise);
        zglfw_pkg.link(exe);
        zopengl_pkg.link(exe);
        zstbi_pkg.link(exe);
        zmath_pkg.link(exe);
        zmesh_pkg.link(exe);
    }
}

const Exercise = struct {
    name: []const u8,
    src: []const u8,
};

fn build_exercise(b: *std.Build, exercise: Exercise) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = exercise.name,
        .root_source_file = .{ .path = exercise.src },
    });

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

    return exe;
}
