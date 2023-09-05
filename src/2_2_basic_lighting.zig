const std = @import("std");

const glfw = @import("zglfw");
const gl = @import("zopengl");
const stbi = @import("zstbi");
const zm = @import("zmath");

const Camera = @import("camera.zig");

const shader = @import("shader.zig");

const SCR_WIDTH: u32 = 800;
const SCR_HEIGHT: u32 = 600;

var scr_width_actual = SCR_WIDTH;
var scr_height_actual = SCR_HEIGHT;

var deltaTime: f32 = 0.0; // time between current frame and last frame
var lastFrame: f32 = 0.0; // time of last frame

var camera = Camera.create(.{ 0.0, 0.0, 3.0, 1.0 }, .{ 0.0, 1.0, 0.0, 0.0 }, -90.0, 0.0);
var lastX: f32 = @as(f32, SCR_WIDTH) / 2.0;
var lastY: f32 = @as(f32, SCR_HEIGHT) / 2.0;
var firstMouse = false;

var lightPos: zm.Vec = .{ 1.2, 1.0, 2.0, 1.0 };

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

    glfw.Window.setInputMode(window, glfw.InputMode.cursor, glfw.Cursor.Mode.disabled);
    _ = glfw.Window.setCursorPosCallback(window, mouseCallback);
    _ = glfw.Window.setScrollCallback(window, scrollCallback);

    // zopengl : load all OpenGL function pointers
    // -------------------------------------------
    gl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor) catch |err| {
        std.log.err("Failed to initialize zopengl:\n{}", .{err});
        std.process.exit(1);
    };

    var allocator = std.heap.page_allocator;

    // initialize stb_image lib
    stbi.init(allocator);
    defer stbi.deinit();
    stbi.setFlipVerticallyOnLoad(true);

    // configure global opengl state
    gl.enable(gl.DEPTH_TEST);

    const lightingShader = try shader.create(allocator, "shaders/2_2_basic_lighting.vert", "shaders/2_2_basic_lighting.frag");
    const lightCubeShader = try shader.create(allocator, "shaders/2_0_light_cube.vert", "shaders/2_0_light_cube.frag");

    // set up vertex data (and buffer(s)) and configure vertex attributes
    const vertices = [_]f32{
        -0.5, -0.5, -0.5, 0.0,  0.0,  -1.0,
        0.5,  -0.5, -0.5, 0.0,  0.0,  -1.0,
        0.5,  0.5,  -0.5, 0.0,  0.0,  -1.0,
        0.5,  0.5,  -0.5, 0.0,  0.0,  -1.0,
        -0.5, 0.5,  -0.5, 0.0,  0.0,  -1.0,
        -0.5, -0.5, -0.5, 0.0,  0.0,  -1.0,

        -0.5, -0.5, 0.5,  0.0,  0.0,  1.0,
        0.5,  -0.5, 0.5,  0.0,  0.0,  1.0,
        0.5,  0.5,  0.5,  0.0,  0.0,  1.0,
        0.5,  0.5,  0.5,  0.0,  0.0,  1.0,
        -0.5, 0.5,  0.5,  0.0,  0.0,  1.0,
        -0.5, -0.5, 0.5,  0.0,  0.0,  1.0,

        -0.5, 0.5,  0.5,  -1.0, 0.0,  0.0,
        -0.5, 0.5,  -0.5, -1.0, 0.0,  0.0,
        -0.5, -0.5, -0.5, -1.0, 0.0,  0.0,
        -0.5, -0.5, -0.5, -1.0, 0.0,  0.0,
        -0.5, -0.5, 0.5,  -1.0, 0.0,  0.0,
        -0.5, 0.5,  0.5,  -1.0, 0.0,  0.0,

        0.5,  0.5,  0.5,  1.0,  0.0,  0.0,
        0.5,  0.5,  -0.5, 1.0,  0.0,  0.0,
        0.5,  -0.5, -0.5, 1.0,  0.0,  0.0,
        0.5,  -0.5, -0.5, 1.0,  0.0,  0.0,
        0.5,  -0.5, 0.5,  1.0,  0.0,  0.0,
        0.5,  0.5,  0.5,  1.0,  0.0,  0.0,

        -0.5, -0.5, -0.5, 0.0,  -1.0, 0.0,
        0.5,  -0.5, -0.5, 0.0,  -1.0, 0.0,
        0.5,  -0.5, 0.5,  0.0,  -1.0, 0.0,
        0.5,  -0.5, 0.5,  0.0,  -1.0, 0.0,
        -0.5, -0.5, 0.5,  0.0,  -1.0, 0.0,
        -0.5, -0.5, -0.5, 0.0,  -1.0, 0.0,

        -0.5, 0.5,  -0.5, 0.0,  1.0,  0.0,
        0.5,  0.5,  -0.5, 0.0,  1.0,  0.0,
        0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
        0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
        -0.5, 0.5,  0.5,  0.0,  1.0,  0.0,
        -0.5, 0.5,  -0.5, 0.0,  1.0,  0.0,
    };
    var vbo: u32 = undefined;
    var cubeVao: u32 = undefined;

    gl.genVertexArrays(1, &cubeVao);
    gl.genBuffers(1, &vbo);
    // optional cleanup
    defer gl.deleteVertexArrays(1, &cubeVao);
    defer gl.deleteBuffers(1, &vbo);

    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, gl.STATIC_DRAW);

    gl.bindVertexArray(cubeVao);

    // position attribute
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
    gl.enableVertexAttribArray(1);

    var lightCubeVao: u32 = undefined;
    gl.genVertexArrays(1, &lightCubeVao);
    defer gl.deleteVertexArrays(1, &lightCubeVao);
    gl.bindVertexArray(lightCubeVao);

    // we only need to bind to the VBO, the container's VBO's data already contains the correct data.
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);

    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);

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
        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // be sure to activate shader when setting uniforms/drawing objects
        lightingShader.use();
        lightingShader.setVec3("objectColor", .{ 1.0, 0.5, 0.31 });
        lightingShader.setVec3("lightColor", .{ 1.0, 1.0, 1.0 });
        lightingShader.setVec3("lightPos", .{ lightPos[0], lightPos[1], lightPos[2] });
        lightingShader.setVec3("viewPos", .{ camera.position[0], camera.position[1], camera.position[2] });

        // view/projection transformations
        const projection = zm.perspectiveFovRhGl(std.math.degreesToRadians(f32, camera.zoom), @as(f32, @floatFromInt(scr_width_actual)) / @as(f32, @floatFromInt(scr_height_actual)), 0.1, 100.0);
        const view = camera.getViewMatrix();
        lightingShader.setMatrix4("projection", false, zm.matToArr(projection));
        lightingShader.setMatrix4("view", false, view);

        // world transformation
        var model = zm.identity();
        lightingShader.setMatrix4("model", false, zm.matToArr(model));

        // render the cube
        gl.bindVertexArray(cubeVao);
        gl.drawArrays(gl.TRIANGLES, 0, 36);

        // also draw the lamp object
        lightCubeShader.use();
        lightCubeShader.setMatrix4("projection", false, zm.matToArr(projection));
        lightCubeShader.setMatrix4("view", false, view);
        model = zm.mul(zm.scaling(0.2, 0.2, 0.2), zm.translation(lightPos[0], lightPos[1], lightPos[2]));
        lightCubeShader.setMatrix4("model", false, zm.matToArr(model));

        gl.bindVertexArray(lightCubeVao);
        gl.drawArrays(gl.TRIANGLES, 0, 36);

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

    if (glfw.Window.getKey(window, glfw.Key.w) == glfw.Action.press) {
        camera.processMovement(Camera.Movement.forward, deltaTime);
    }
    if (glfw.Window.getKey(window, glfw.Key.s) == glfw.Action.press) {
        camera.processMovement(Camera.Movement.backward, deltaTime);
    }
    if (glfw.Window.getKey(window, glfw.Key.a) == glfw.Action.press) {
        camera.processMovement(Camera.Movement.left, deltaTime);
    }
    if (glfw.Window.getKey(window, glfw.Key.d) == glfw.Action.press) {
        camera.processMovement(Camera.Movement.right, deltaTime);
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

    camera.processMovement(Camera.Movement{ .rotate = .{ .deltaX = xoffset, .deltaY = yoffset } }, deltaTime);
}

fn scrollCallback(window: *glfw.Window, xoffset: f64, yoffset: f64) callconv(.C) void {
    _ = xoffset;
    _ = window;
    camera.processMovement(Camera.Movement{ .zoom = @as(f32, @floatCast(yoffset)) }, deltaTime);
}
