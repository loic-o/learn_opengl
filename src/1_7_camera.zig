const std = @import("std");

const glfw = @import("zglfw");
const gl = @import("zopengl");
const stbi = @import("zstbi");
const zm = @import("zmath");

const shader = @import("shader.zig");

const SCR_WIDTH: u32 = 800;
const SCR_HEIGHT: u32 = 600;

var scr_width_actual = SCR_WIDTH;
var scr_height_actual = SCR_HEIGHT;

var deltaTime: f32 = 0.0; // time between current frame and last frame
var lastFrame: f32 = 0.0; // time of last frame

var pitch: f32 = 0.0;
var yaw: f32 = -90.0;
var fov: f32 = 45.0;

var firstMouse = false;
var lastX: f32 = 400;
var lastY: f32 = 300;

var cameraPos = zm.f32x4(0.0, 0.0, 3.0, 1.0);
var cameraFront = zm.f32x4(0.0, 0.0, -1.0, 1.0);
var cameraUp = zm.f32x4(0.0, 1.0, 0.0, 1.0);

inline fn degToRad(degrees: f32) f32 {
    return degrees * std.math.pi / 180.0;
}

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

    glfw.Window.setInputMode(window, glfw.InputMode.cursor, glfw.Cursor.Mode.disabled);
    _ = glfw.Window.setCursorPosCallback(window, mouseCallback);
    _ = glfw.Window.setScrollCallback(window, scrollCallback);

    var allocator = std.heap.page_allocator;

    // initialize stb_image lib
    stbi.init(allocator);
    defer stbi.deinit();
    stbi.setFlipVerticallyOnLoad(true);

    gl.enable(gl.DEPTH_TEST);

    const ourShader = try shader.create(allocator, "shaders/1_7_shader.vert", "shaders/1_7_shader.frag");

    // set up vertex data (and buffer(s)) and configure vertex attributes
    const vertices = [_]f32{
        -0.5, -0.5, -0.5, 0.0, 0.0,
        0.5,  -0.5, -0.5, 1.0, 0.0,
        0.5,  0.5,  -0.5, 1.0, 1.0,
        0.5,  0.5,  -0.5, 1.0, 1.0,
        -0.5, 0.5,  -0.5, 0.0, 1.0,
        -0.5, -0.5, -0.5, 0.0, 0.0,
        -0.5, -0.5, 0.5,  0.0, 0.0,
        0.5,  -0.5, 0.5,  1.0, 0.0,
        0.5,  0.5,  0.5,  1.0, 1.0,
        0.5,  0.5,  0.5,  1.0, 1.0,
        -0.5, 0.5,  0.5,  0.0, 1.0,
        -0.5, -0.5, 0.5,  0.0, 0.0,
        -0.5, 0.5,  0.5,  1.0, 0.0,
        -0.5, 0.5,  -0.5, 1.0, 1.0,
        -0.5, -0.5, -0.5, 0.0, 1.0,
        -0.5, -0.5, -0.5, 0.0, 1.0,
        -0.5, -0.5, 0.5,  0.0, 0.0,
        -0.5, 0.5,  0.5,  1.0, 0.0,
        0.5,  0.5,  0.5,  1.0, 0.0,
        0.5,  0.5,  -0.5, 1.0, 1.0,
        0.5,  -0.5, -0.5, 0.0, 1.0,
        0.5,  -0.5, -0.5, 0.0, 1.0,
        0.5,  -0.5, 0.5,  0.0, 0.0,
        0.5,  0.5,  0.5,  1.0, 0.0,
        -0.5, -0.5, -0.5, 0.0, 1.0,
        0.5,  -0.5, -0.5, 1.0, 1.0,
        0.5,  -0.5, 0.5,  1.0, 0.0,
        0.5,  -0.5, 0.5,  1.0, 0.0,
        -0.5, -0.5, 0.5,  0.0, 0.0,
        -0.5, -0.5, -0.5, 0.0, 1.0,
        -0.5, 0.5,  -0.5, 0.0, 1.0,
        0.5,  0.5,  -0.5, 1.0, 1.0,
        0.5,  0.5,  0.5,  1.0, 0.0,
        0.5,  0.5,  0.5,  1.0, 0.0,
        -0.5, 0.5,  0.5,  0.0, 0.0,
        -0.5, 0.5,  -0.5, 0.0, 1.0,
    };
    const cubePositions = [_][3]f32{
        .{ 0.0, 0.0, 0.0 },
        .{ 2.0, 5.0, -15.0 },
        .{ -1.5, -2.2, -2.5 },
        .{ -3.8, -2.0, -12.3 },
        .{ 2.4, -0.4, -3.5 },
        .{ -1.7, 3.0, -7.5 },
        .{ 1.3, -2.0, -2.5 },
        .{ 1.5, 2.0, -2.5 },
        .{ 1.5, 0.2, -1.5 },
        .{ -1.3, 1.0, -1.5 },
    };
    var vbo: u32 = undefined;
    var vao: u32 = undefined;

    gl.genVertexArrays(1, &vao);
    gl.genBuffers(1, &vbo);
    // optional cleanup
    defer gl.deleteVertexArrays(1, &vao);
    defer gl.deleteBuffers(1, &vbo);

    // bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
    gl.bindVertexArray(vao);

    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, gl.STATIC_DRAW);

    // position attribute
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);
    // texture coord attribute
    gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
    gl.enableVertexAttribArray(1);

    // load and create a texture
    // -------------------------
    var image: stbi.Image = undefined;
    var texture1: u32 = undefined;
    var texture2: u32 = undefined;
    // texture 1
    // ---------
    gl.genTextures(1, &texture1);
    gl.bindTexture(gl.TEXTURE_2D, texture1);
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
    image.deinit();
    // texture 2
    // ---------
    gl.genTextures(1, &texture2);
    gl.bindTexture(gl.TEXTURE_2D, texture2);
    // set the texture wrapping parameters
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    // set texture filtering parameters
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    // load image, create texture and generate mipmaps
    image = try stbi.Image.loadFromFile("textures/awesomeface.png", 0);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, @intCast(image.width), @intCast(image.height), 0, gl.RGBA, gl.UNSIGNED_BYTE, @ptrCast(image.data));
    gl.generateMipmap(gl.TEXTURE_2D);
    image.deinit();

    // tell opengl for each sampler to which texture unit it belongs to (only has to be done once)
    // -------------------------------------------------------------------------------------------
    ourShader.use();
    // either set it manually like so:
    gl.uniform1i(gl.getUniformLocation(ourShader.id, "texture1"), 0);
    // or set it via the shader class
    ourShader.setInt("texture2", 1);

    // render loop
    // -----------
    while (!window.shouldClose()) {
        const currentFrame: f32 = @floatCast(glfw.getTime());
        deltaTime = currentFrame - lastFrame;
        lastFrame = currentFrame;

        // input
        processInput(window);

        // render
        // ------
        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // bind Textures
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, texture1);
        gl.activeTexture(gl.TEXTURE1);
        gl.bindTexture(gl.TEXTURE_2D, texture2);

        // retner container
        ourShader.use();

        const projection = zm.perspectiveFovRhGl(degToRad(fov), @as(f32, @floatFromInt(scr_width_actual)) / @as(f32, @floatFromInt(scr_height_actual)), 0.1, 100.0);
        ourShader.setMatrix4("projection", false, zm.matToArr(projection));

        // const view = zm.translation(0.0, 0.0, -3.0);
        const view = zm.lookAtRh(cameraPos, cameraPos + cameraFront, cameraUp);
        ourShader.setMatrix4("view", false, zm.matToArr(view));

        gl.bindVertexArray(vao);
        for (cubePositions, 0..) |pos, i| {
            const angle: f32 = 20.0 * @as(f32, @floatFromInt(i));
            // const model = zm.mul(zm.translation(pos[0], pos[1], pos[2]), zm.matFromAxisAngle(.{ 1.0, 0.3, 0.5, 0.0 }, degToRad(angle)));
            const model = zm.mul(zm.matFromAxisAngle(.{ 1.0, 0.3, 0.5, 0.0 }, degToRad(angle)), zm.translation(pos[0], pos[1], pos[2]));
            ourShader.setMatrix4("model", false, zm.matToArr(model));
            gl.drawArrays(gl.TRIANGLES, 0, 36);
        }

        // glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
        window.swapBuffers();
        glfw.pollEvents();
    }
}

fn framebufferSizeCallback(window: *glfw.Window, width: i32, height: i32) callconv(.C) void {
    _ = window;
    gl.viewport(0, 0, width, height);
    scr_width_actual = @intCast(width);
    scr_height_actual = @intCast(height);
    // std.log.debug("resize callback in affect", .{});
}

fn processInput(window: *glfw.Window) void {
    if (glfw.Window.getKey(window, glfw.Key.escape) == glfw.Action.press) {
        glfw.Window.setShouldClose(window, true);
    }

    const cameraSpeed: f32 = 2.5 * deltaTime;

    if (glfw.Window.getKey(window, glfw.Key.w) == glfw.Action.press) {
        cameraPos += zm.f32x4s(cameraSpeed) * cameraFront;
    }
    if (glfw.Window.getKey(window, glfw.Key.s) == glfw.Action.press) {
        cameraPos -= zm.f32x4s(cameraSpeed) * cameraFront;
    }
    if (glfw.Window.getKey(window, glfw.Key.a) == glfw.Action.press) {
        cameraPos -= zm.normalize3(zm.cross3(cameraFront, cameraUp)) * zm.f32x4s(cameraSpeed);
    }
    if (glfw.Window.getKey(window, glfw.Key.d) == glfw.Action.press) {
        cameraPos += zm.normalize3(zm.cross3(cameraFront, cameraUp)) * zm.f32x4s(cameraSpeed);
    }
}

fn mouseCallback(window: *glfw.Window, xpos: f64, ypos: f64) callconv(.C) void {
    _ = window;
    if (firstMouse) {
        lastX = @floatCast(xpos);
        lastY = @floatCast(ypos);
        firstMouse = false;
    }

    var xoffset: f32 = @as(f32, @floatCast(xpos)) - lastX;
    var yoffset: f32 = lastY - @as(f32, @floatCast(ypos)); // reversed since y-coordinates go from bottom to top
    lastX = @floatCast(xpos);
    lastY = @floatCast(ypos);

    const sensitivity: f32 = 0.1;
    xoffset *= sensitivity;
    yoffset *= sensitivity;

    yaw += xoffset;
    pitch += yoffset;

    if (pitch > 89.0) {
        pitch = 89.0;
    }
    if (pitch < -89.0) {
        pitch = -89.0;
    }

    cameraFront = zm.normalize3(.{
        std.math.cos(degToRad(yaw)) * std.math.cos(degToRad(pitch)),
        std.math.sin(degToRad(pitch)),
        std.math.sin(degToRad(yaw)) * std.math.cos(degToRad(pitch)),
        1.0,
    });
}

fn scrollCallback(window: *glfw.Window, xoffset: f64, yoffset: f64) callconv(.C) void {
    _ = xoffset;
    _ = window;
    fov -= @as(f32, @floatCast(yoffset));
    if (fov < 1.0) {
        fov = 1.0;
    }
    if (fov > 45.0) {
        fov = 45.0;
    }
}
