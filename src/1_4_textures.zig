const std = @import("std");

const glfw = @import("zglfw");
const gl = @import("zopengl");
const stbi = @import("zstbi");

const shader = @import("shader.zig");

const SCR_WIDTH: u32 = 800;
const SCR_HEIGHT: u32 = 600;

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    // glfw: initialize and configure
    // ------------------------------
    const gl_major = 3;
    const gl_minor = 3;
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);

    // glfw window creation
    // --------------------
    const window = glfw.Window.create(SCR_WIDTH, SCR_HEIGHT, "learn opengl", null) catch |err| {
        std.log.err("Failed to create GLFW window:\n{}", .{err});
        std.process.exit(1);
    };
    defer window.destroy();
    glfw.makeContextCurrent(window);
    if (glfw.Window.setFramebufferSizeCallback(window, framebufferSizeCallback)) |_| {} else {
        std.log.debug("setFramebufferSizeCallback returned null", .{});
    }

    // zopengl : load all OpenGL function pointers
    // -------------------------------------------
    gl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor) catch |err| {
        std.log.err("Failed to initialize zopengl:\n{}", .{err});
        std.process.exit(1);
    };

    var allocator = std.heap.page_allocator;

    stbi.init(allocator);
    defer stbi.deinit();

    const my_shader = try shader.create(allocator, "shaders/1_4_shader.vert", "shaders/1_4_shader.frag");

    // set up vertex data (and buffer(s)) and configure vertex attributes
    const vertices = [_]f32{ // positions          // colors           // texture coords
        0.5, 0.5, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, // top right
        0.5, -0.5, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, // bottom right
        -0.5, -0.5, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, // bottom left
        -0.5, 0.5, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, // top left
    };
    const indices = [_]u32{
        0, 1, 3, // first triangle
        1, 2, 3, // second triangle
    };

    var vbo: u32 = undefined;
    var vao: u32 = undefined;
    var ebo: u32 = undefined;

    gl.genVertexArrays(1, &vao);
    gl.genBuffers(1, &vbo);
    gl.genBuffers(1, &ebo);
    // optional cleanup
    defer gl.deleteVertexArrays(1, &vao);
    defer gl.deleteBuffers(1, &vbo);
    defer gl.deleteBuffers(1, &ebo);

    // bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
    gl.bindVertexArray(vao);

    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, gl.STATIC_DRAW);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices.len * @sizeOf(u32), &indices, gl.STATIC_DRAW);

    // position attribute
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);
    // color attribute
    gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
    gl.enableVertexAttribArray(1);
    // texture coord attribute
    gl.vertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @ptrFromInt(6 * @sizeOf(f32)));
    gl.enableVertexAttribArray(2);

    // load and create a texture
    // -------------------------
    var image: stbi.Image = undefined;
    var texture: u32 = undefined;
    gl.genTextures(1, &texture);
    gl.bindTexture(gl.TEXTURE_2D, texture);
    // set the texture wrapping parameters
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    // set texture filtering parameters
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    // load image, create texture and generate mipmaps
    image = try stbi.Image.loadFromFile("textures/container.jpg", 0);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, @intCast(image.width), @intCast(image.height), 0, gl.RGB, gl.UNSIGNED_BYTE, @ptrCast(image.data));
    gl.generateMipmap(gl.TEXTURE_2D);
    image.deinit(); // don't think i need to defer this

    // render loop
    // -----------
    while (!window.shouldClose()) {
        // input
        processInput(window);

        // render
        // ------
        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);

        // bind Texture
        gl.bindTexture(gl.TEXTURE_2D, texture);

        // retner container
        my_shader.use();
        gl.bindVertexArray(vao);
        gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);

        // glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
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
