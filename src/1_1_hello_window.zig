const std = @import("std");

const glfw = @import("zglfw");
const gl = @import("zopengl");

const SCR_WIDTH: u32 = 800;
const SCR_HEIGHT: u32 = 600;

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    const gl_major = 3;
    const gl_minor = 3;
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);

    const window = glfw.Window.create(SCR_WIDTH, SCR_HEIGHT, "learn opengl", null) catch |err| {
        std.log.err("Failed to create GLFW window:\n{}", .{err});
        std.process.exit(1);
    };
    defer window.destroy();
    glfw.makeContextCurrent(window);
    if (glfw.Window.setFramebufferSizeCallback(window, framebufferSizeCallback)) |_| {} else {
        std.log.debug("setFramebufferSizeCallback returned null", .{});
    }

    gl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor) catch |err| {
        std.log.err("Failed to initialize zopengl:\n{}", .{err});
        std.process.exit(1);
    };

    while (!window.shouldClose()) {
        // input
        processInput(window);

        // glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        window.swapBuffers();
        glfw.pollEvents();
    }
}

fn framebufferSizeCallback(window: *glfw.Window, width: i32, height: i32) callconv(.C) void {
    _ = window;
    gl.viewport(0, 0, width, height);
    // std.log.debug("resize callback in affect", .{});
}

fn processInput(window: *glfw.Window) void {
    if (glfw.Window.getKey(window, glfw.Key.escape) == glfw.Action.press) {
        glfw.Window.setShouldClose(window, true);
    }
}
