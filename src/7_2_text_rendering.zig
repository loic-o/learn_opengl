const std = @import("std");

const glfw = @import("zglfw");
const zmath = @import("zmath");
const gl = @import("zopengl");
const ft = @import("freetype");

const sh = @import("shader.zig");

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;

const Character = struct {
    texture_id: u32,
    size: zmath.Vec,
    bearing: zmath.Vec,
    advance: u32,
};

var vao: u32 = undefined;
var vbo: u32 = undefined;

var characters: std.AutoHashMap(u8, Character) = undefined;

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

    const window = glfw.Window.create(SCREEN_WIDTH, SCREEN_HEIGHT, "learn opengl", null) catch |err| {
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

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const shader = try sh.create(allocator, "shaders/text.vert", "shaders/text.frag");
    const proj = zmath.orthographicOffCenterRhGl(0.0, SCREEN_WIDTH, 0.0, SCREEN_HEIGHT, -1.0, 1.0);
    shader.use();
    shader.setMatrix4("projection", false, zmath.matToArr(proj));

    const lib = try ft.Library.init();
    defer lib.deinit();

    const face = try lib.createFace("fonts/Antonio-Bold.ttf", 0);
    try face.setPixelSizes(0, 48);

    gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);

    characters = std.AutoHashMap(u8, Character).init(allocator);
    defer characters.deinit();

    // load the first 128 chars of ASCII set
    for (0..128) |i| {
        try face.loadChar(@intCast(i), .{ .render = true });
        var texture: u32 = undefined;
        gl.genTextures(1, &texture);
        gl.bindTexture(gl.TEXTURE_2D, texture);
        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RED,
            @intCast(face.glyph().bitmap().width()),
            @intCast(face.glyph().bitmap().rows()),
            0,
            gl.RED,
            gl.UNSIGNED_BYTE,
            @ptrCast(face.glyph().bitmap().buffer()),
        );
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        // now store soem char for later use
        const character = Character{
            .texture_id = texture,
            .size = zmath.f32x4(@floatFromInt(face.glyph().bitmap().width()), @floatFromInt(face.glyph().bitmap().rows()), 0, 0),
            .bearing = zmath.f32x4(@floatFromInt(face.glyph().bitmapLeft()), @floatFromInt(face.glyph().bitmapTop()), 0, 0),
            .advance = @intCast(face.glyph().advance().x),
        };
        try characters.put(@intCast(i), character);
    }
    face.deinit();

    gl.genVertexArrays(1, &vao);
    gl.genBuffers(1, &vbo);
    gl.bindVertexArray(vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * 6 * 4, null, gl.DYNAMIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, @sizeOf(f32) * 4, null);
    gl.bindBuffer(gl.ARRAY_BUFFER, 0);
    gl.bindVertexArray(0);

    gl.enable(gl.CULL_FACE);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    while (!window.shouldClose()) {
        // input
        processInput(window);

        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);

        try renderText(shader, "This is sample text", 25.0, 25.0, 1.0, zmath.f32x4(0.5, 0.8, 0.2, 1.0));
        try renderText(shader, "(c) LearnOpenGL.com", 540.0, 570.0, 0.5, zmath.f32x4(0.3, 0.7, 0.9, 1.0));

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

fn renderText(shader: sh.Shader, text: []const u8, text_x: f32, y: f32, scale: f32, color: zmath.Vec) !void {
    var x = text_x;
    shader.use();
    shader.setVec3("textColor", [3]f32{ color[0], color[1], color[2] });
    gl.activeTexture(gl.TEXTURE0);
    gl.bindVertexArray(vao);

    for (text) |c| {
        const ch = characters.get(c).?;
        const xpos = x + ch.bearing[0] * scale;
        const ypos = y - (ch.size[1] - ch.bearing[1]) * scale;

        const w = ch.size[0] * scale;
        const h = ch.size[1] * scale;

        const vertices = [6 * 4]f32{
            xpos,     ypos + h, 0.0, 0.0,
            xpos,     ypos,     0.0, 1.0,
            xpos + w, ypos,     1.0, 1.0,

            xpos,     ypos + h, 0.0, 0.0,
            xpos + w, ypos,     1.0, 1.0,
            xpos + w, ypos + h, 1.0, 0.0,
        };
        // render glyph texture over quad
        gl.bindTexture(gl.TEXTURE_2D, ch.texture_id);
        // update content of vbo memory
        gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
        gl.bufferSubData(gl.ARRAY_BUFFER, 0, @sizeOf(f32) * vertices.len, &vertices);
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
        // render quad
        gl.drawArrays(gl.TRIANGLES, 0, 6);
        // now advance cursors for next glyph (note that advance is number of 1/64 pixels)
        x += @as(f32, @floatFromInt(ch.advance >> 6)) * scale;
    }
    gl.bindVertexArray(0);
    gl.bindTexture(gl.TEXTURE_2D, 0);
}
