const std = @import("std");

const glfw = @import("zglfw");
const gl = @import("zopengl");
const stbi = @import("zstbi");
const zmath = @import("zmath");

const Camera = @import("camera.zig");
const sh = @import("shader.zig");
const Shader = sh.Shader;

const SCR_WIDTH: u32 = 800;
const SCR_HEIGHT: u32 = 600;

var camera: Camera = Camera.create(zmath.f32x4(0, 0, 3, 1), zmath.f32x4(0, 1, 0, 0), -90, 0);
var last_x = @as(f32, @floatFromInt(SCR_WIDTH)) / 2.0;
var last_y = @as(f32, @floatFromInt(SCR_HEIGHT)) / 2.0;
var first_mouse: bool = true;

var delta_time: f32 = 0;
var last_frame: f32 = 0;

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
    _ = glfw.Window.setFramebufferSizeCallback(window, framebufferSizeCallback);
    _ = glfw.Window.setCursorPosCallback(window, mouseCallback);
    _ = glfw.Window.setScrollCallback(window, scrollCallback);

    glfw.Window.setInputMode(window, glfw.InputMode.cursor, glfw.Cursor.Mode.disabled);

    gl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor) catch |err| {
        std.log.err("Failed to initialize zopengl:\n{}", .{err});
        std.process.exit(1);
    };

    gl.enable(gl.DEPTH_TEST);
    gl.depthFunc(gl.LESS);
    gl.enable(gl.CULL_FACE);
    gl.cullFace(gl.BACK);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    stbi.init(allocator);

    var shader: Shader = try sh.create(allocator, "shaders/4_1_depth_testing.vert", "shaders/4_1_depth_testing.frag");
    var screen_shader: Shader = try sh.create(allocator, "shaders/4_5_framebuffers.vert", "shaders/4_5_framebuffers.frag");

    const cube_vertices = [_]f32{
        // Back ace
        -0.5, -0.5, -0.5, 0.0, 0.0, // Bottom-let
        0.5, 0.5, -0.5, 1.0, 1.0, // top-right
        0.5, -0.5, -0.5, 1.0, 0.0, // bottom-right
        0.5, 0.5, -0.5, 1.0, 1.0, // top-right
        -0.5, -0.5, -0.5, 0.0, 0.0, // bottom-let
        -0.5, 0.5, -0.5, 0.0, 1.0, // top-let
        // ront ace
        -0.5, -0.5, 0.5, 0.0, 0.0, // bottom-let
        0.5, -0.5, 0.5, 1.0, 0.0, // bottom-right
        0.5, 0.5, 0.5, 1.0, 1.0, // top-right
        0.5, 0.5, 0.5, 1.0, 1.0, // top-right
        -0.5, 0.5, 0.5, 0.0, 1.0, // top-let
        -0.5, -0.5, 0.5, 0.0, 0.0, // bottom-let
        // Let ace
        -0.5, 0.5, 0.5, 1.0, 0.0, // top-right
        -0.5, 0.5, -0.5, 1.0, 1.0, // top-let
        -0.5, -0.5, -0.5, 0.0, 1.0, // bottom-let
        -0.5, -0.5, -0.5, 0.0, 1.0, // bottom-let
        -0.5, -0.5, 0.5, 0.0, 0.0, // bottom-right
        -0.5, 0.5, 0.5, 1.0, 0.0, // top-right
        // Right ace
        0.5, 0.5, 0.5, 1.0, 0.0, // top-let
        0.5, -0.5, -0.5, 0.0, 1.0, // bottom-right
        0.5, 0.5, -0.5, 1.0, 1.0, // top-right
        0.5, -0.5, -0.5, 0.0, 1.0, // bottom-right
        0.5, 0.5, 0.5, 1.0, 0.0, // top-let
        0.5, -0.5, 0.5, 0.0, 0.0, // bottom-let
        // Bottom ace
        -0.5, -0.5, -0.5, 0.0, 1.0, // top-right
        0.5, -0.5, -0.5, 1.0, 1.0, // top-let
        0.5, -0.5, 0.5, 1.0, 0.0, // bottom-let
        0.5, -0.5, 0.5, 1.0, 0.0, // bottom-let
        -0.5, -0.5, 0.5, 0.0, 0.0, // bottom-right
        -0.5, -0.5, -0.5, 0.0, 1.0, // top-right
        // Top ace
        -0.5, 0.5, -0.5, 0.0, 1.0, // top-let
        0.5, 0.5, 0.5, 1.0, 0.0, // bottom-right
        0.5, 0.5, -0.5, 1.0, 1.0, // top-right
        0.5, 0.5, 0.5, 1.0, 0.0, // bottom-right
        -0.5, 0.5, -0.5, 0.0, 1.0, // top-let
        -0.5, 0.5, 0.5, 0.0, 0.0, // bottom-let
    };
    const plane_vertices = [_]f32{
        // positions      // texture Coords (note we set these higher than 1
        //                  (together with GL_REPEAT as texture wrapping mode).
        //                  this will cause the floor texture to repeat)
        5.0,  -0.5, 5.0,  2.0, 0.0,
        -5.0, -0.5, -5.0, 0.0, 2.0,
        -5.0, -0.5, 5.0,  0.0, 0.0,

        5.0,  -0.5, 5.0,  2.0, 0.0,
        5.0,  -0.5, -5.0, 2.0, 2.0,
        -5.0, -0.5, -5.0, 0.0, 2.0,
    };

    const screen_quad_vertices = [_]f32{
        -1.0, 1.0,  0.0, 1.0,
        -1.0, -1.0, 0.0, 0.0,
        1.0,  -1.0, 1.0, 0.0,

        -1.0, 1.0,  0.0, 1.0,
        1.0,  -1.0, 1.0, 0.0,
        1.0,  1.0,  1.0, 1.0,
    };

    var quad_vao: u32 = undefined;
    var quad_vbo: u32 = undefined;
    gl.genVertexArrays(1, &quad_vao);
    gl.genBuffers(1, &quad_vbo);
    gl.bindVertexArray(quad_vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, quad_vbo);
    gl.bufferData(gl.ARRAY_BUFFER, screen_quad_vertices.len * @sizeOf(f32), &screen_quad_vertices, gl.STATIC_DRAW);
    // position
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), null);
    // tex coords
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32)));
    gl.bindVertexArray(0);

    // cube VAO
    var cube_vao: u32 = undefined;
    var cube_vbo: u32 = undefined;
    gl.genVertexArrays(1, &cube_vao);
    gl.genBuffers(1, &cube_vbo);
    gl.bindVertexArray(cube_vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, cube_vbo);
    gl.bufferData(gl.ARRAY_BUFFER, cube_vertices.len * @sizeOf(f32), &cube_vertices, gl.STATIC_DRAW);
    // position
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), null);
    // texture coords
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
    gl.bindVertexArray(0);

    // plane VAO
    var plane_vao: u32 = undefined;
    var plane_vbo: u32 = undefined;
    gl.genVertexArrays(1, &plane_vao);
    gl.genBuffers(1, &plane_vbo);
    gl.bindVertexArray(plane_vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, plane_vbo);
    gl.bufferData(gl.ARRAY_BUFFER, plane_vertices.len * @sizeOf(f32), &plane_vertices, gl.STATIC_DRAW);
    // position
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), null);
    // texture coords
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
    gl.bindVertexArray(0);

    const cube_texture = try loadTexture("textures/container.jpg");
    const plane_texture = try loadTexture("textures/metal.png");

    shader.use();
    shader.setInt("texture1", 0);

    screen_shader.use();
    screen_shader.setInt("screenTexture", 0);

    // create and bind a frambuffer object
    var framebuffer: u32 = undefined;
    gl.genFramebuffers(1, &framebuffer);
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);

    // generate a texture
    var texture_colorbuffer: u32 = undefined;
    gl.genTextures(1, &texture_colorbuffer);
    gl.bindTexture(gl.TEXTURE_2D, texture_colorbuffer);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, SCR_WIDTH, SCR_HEIGHT, 0, gl.RGB, gl.UNSIGNED_BYTE, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    // attach it to currently bound ramebuffer object
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture_colorbuffer, 0);

    // generate renderbuffer for depth/stencil
    var rbo: u32 = undefined;
    gl.genRenderbuffers(1, &rbo);
    gl.bindRenderbuffer(gl.RENDERBUFFER, rbo);
    gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, SCR_WIDTH, SCR_HEIGHT);
    // attach it to currently bound framebuffer object
    gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, rbo);

    if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
        std.log.err("ERROR::FRAMEBUFFER:: Framebuffer is not complete.", .{});
        return error.IncompleteFramebuffer;
    }
    gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

    while (!window.shouldClose()) {
        // per-frame time logic
        // --------------------
        const current_frame: f32 = @floatCast(glfw.getTime());
        delta_time = current_frame - last_frame;
        last_frame = current_frame;

        // input
        // ------
        processInput(window);

        // render
        // ------
        gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
        gl.enable(gl.DEPTH_TEST);

        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        shader.use();
        var model = zmath.identity();
        const view = camera.getViewMatrix();
        const projection = zmath.perspectiveFovRhGl(
            std.math.degreesToRadians(f32, 45.0),
            @as(f32, @floatFromInt(SCR_WIDTH)) / @as(f32, @floatFromInt(SCR_HEIGHT)),
            0.1,
            100.0,
        );
        shader.setMatrix4("view", false, view);
        shader.setMatrix4("projection", false, zmath.matToArr(projection));

        // draw the first cube...
        gl.bindVertexArray(cube_vao);
        gl.bindTexture(gl.TEXTURE_2D, cube_texture);
        model = zmath.translation(-1.0, 0.0, -1.0);
        shader.setMatrix4("model", false, zmath.matToArr(model));
        gl.drawArrays(gl.TRIANGLES, 0, 36);
        // draw the second cube...
        model = zmath.translation(2.0, 0.0, 0.0);
        shader.setMatrix4("model", false, zmath.matToArr(model));
        gl.drawArrays(gl.TRIANGLES, 0, 36);
        // draw the floor
        gl.bindVertexArray(plane_vao);
        gl.bindTexture(gl.TEXTURE_2D, plane_texture);
        shader.setMatrix4("model", false, zmath.matToArr(zmath.identity()));
        gl.drawArrays(gl.TRIANGLES, 0, 6);
        gl.bindVertexArray(0);

        // second pass
        // -----------
        gl.bindFramebuffer(gl.FRAMEBUFFER, 0); // back to default
        gl.disable(gl.DEPTH_TEST);
        gl.clearColor(1.0, 1.0, 1.0, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);

        screen_shader.use();
        gl.bindVertexArray(quad_vao);
        gl.bindTexture(gl.TEXTURE_2D, texture_colorbuffer);
        gl.drawArrays(gl.TRIANGLES, 0, 6);

        // glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
        window.swapBuffers();
        glfw.pollEvents();
    }

    // optional: de-allocate all resources once they've outlived their purpose:
    // ------------------------------------------------------------------------
    gl.deleteVertexArrays(1, &quad_vao);
    gl.deleteBuffers(1, &quad_vbo);
    gl.deleteVertexArrays(1, &cube_vao);
    gl.deleteVertexArrays(1, &plane_vao);
    gl.deleteBuffers(1, &cube_vbo);
    gl.deleteBuffers(1, &plane_vbo);
    gl.deleteRenderbuffers(1, &rbo);
    gl.deleteFramebuffers(1, &framebuffer);

    stbi.deinit();
    _ = gpa.deinit();
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
    if (glfw.Window.getKey(window, glfw.Key.w) == glfw.Action.press) {
        if (glfw.Window.getKey(window, glfw.Key.left_shift) == glfw.Action.press) {
            camera.processMovement(Camera.Movement.up, delta_time);
        } else {
            camera.processMovement(Camera.Movement.forward, delta_time);
        }
    }
    if (glfw.Window.getKey(window, glfw.Key.s) == glfw.Action.press) {
        if (glfw.Window.getKey(window, glfw.Key.left_shift) == glfw.Action.press) {
            camera.processMovement(Camera.Movement.down, delta_time);
        } else {
            camera.processMovement(Camera.Movement.backward, delta_time);
        }
    }
    if (glfw.Window.getKey(window, glfw.Key.a) == glfw.Action.press) {
        camera.processMovement(Camera.Movement.left, delta_time);
    }
    if (glfw.Window.getKey(window, glfw.Key.d) == glfw.Action.press) {
        camera.processMovement(Camera.Movement.right, delta_time);
    }
}

fn mouseCallback(window: *glfw.Window, x_pos_in: f64, y_pos_in: f64) callconv(.C) void {
    _ = window;
    const x_pos: f32 = @floatCast(x_pos_in);
    const y_pos: f32 = @floatCast(y_pos_in);

    if (first_mouse) {
        last_x = x_pos;
        last_y = y_pos;
        first_mouse = false;
    }

    var xoffset: f32 = x_pos - last_x;
    var yoffset: f32 = last_y - y_pos; // reversed since y-coordinates go from bottom to top
    last_x = x_pos;
    last_y = y_pos;

    camera.processMovement(Camera.Movement{ .rotate = .{ .deltaX = xoffset, .deltaY = yoffset } }, delta_time);
}

fn scrollCallback(window: *glfw.Window, xoffset: f64, yoffset: f64) callconv(.C) void {
    _ = xoffset;
    _ = window;
    camera.processMovement(Camera.Movement{ .zoom = @as(f32, @floatCast(yoffset)) }, delta_time);
}

fn loadTexture(path: []const u8) !u32 {
    var textureID: u32 = undefined;
    gl.genTextures(1, &textureID);

    var image: stbi.Image = undefined;
    image = stbi.Image.loadFromFile(@ptrCast(path), 0) catch |err| {
        std.log.err("Failed to load texture: {s}\n{}", .{ path, err });
        return err;
    };
    defer image.deinit();

    const format: u32 = switch (image.num_components) {
        1 => gl.RED,
        3 => gl.RGB,
        4 => gl.RGBA,
        else => unreachable,
    };

    gl.bindTexture(gl.TEXTURE_2D, textureID);
    gl.texImage2D(gl.TEXTURE_2D, 0, format, @intCast(image.width), @intCast(image.height), 0, format, gl.UNSIGNED_BYTE, @ptrCast(image.data));
    gl.generateMipmap(gl.TEXTURE_2D);

    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    return textureID;
}
