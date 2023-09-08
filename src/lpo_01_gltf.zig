const std = @import("std");

const glfw = @import("zglfw");
const gl = @import("zopengl");
const zm = @import("zmath");
const zmesh = @import("zmesh");

const Camera = @import("camera.zig");

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

const vertexShaderSource =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\
    \\uniform mat4 model;
    \\uniform mat4 view;
    \\uniform mat4 projection;
    \\
    \\void main() {
    \\    gl_Position = projection * view * model * vec4(aPos, 1.0);
    \\}
;
const fragmentShaderSource =
    \\#version 330 core
    \\out vec4 FragColor;
    \\
    \\void main() {
    \\    FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
    \\}
;

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

    glfw.Window.setInputMode(window, glfw.InputMode.cursor, glfw.Cursor.Mode.normal);
    _ = glfw.Window.setCursorPosCallback(window, mouseCallback);
    _ = glfw.Window.setScrollCallback(window, scrollCallback);

    // zopengl : load all OpenGL function pointers
    // -------------------------------------------
    gl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor) catch |err| {
        std.log.err("Failed to initialize zopengl:\n{}", .{err});
        std.process.exit(1);
    };

    // build and compile our shader program
    // ------------------------------------
    var success: i32 = undefined;
    var infoLog: [512]u8 = undefined;
    // vertex shader
    // -------------
    const vertexShader = gl.createShader(gl.VERTEX_SHADER);
    const vertexShaderSourcePtr: [*]const u8 = vertexShaderSource.ptr;
    gl.shaderSource(vertexShader, 1, &vertexShaderSourcePtr, null);
    gl.compileShader(vertexShader);
    // check for shader compile errors
    gl.getShaderiv(vertexShader, gl.COMPILE_STATUS, &success);
    if (success == 0) {
        gl.getShaderInfoLog(vertexShader, 512, null, &infoLog);
        std.log.err("ERROR::SHADER::VERTEX::COMPILATION_FAILED\n{s}", .{infoLog});
        std.process.exit(3);
    }
    // fragment shader
    // ---------------
    const fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
    const fragmentShaderSourcePtr: [*]const u8 = fragmentShaderSource.ptr;
    gl.shaderSource(fragmentShader, 1, &fragmentShaderSourcePtr, null);
    gl.compileShader(fragmentShader);
    // check for shader compile errors
    gl.getShaderiv(fragmentShader, gl.COMPILE_STATUS, &success);
    if (success == 0) {
        gl.getShaderInfoLog(fragmentShader, 512, null, &infoLog);
        std.log.err("ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n{s}", .{infoLog});
        std.process.exit(3);
    }
    // link shaders
    const shaderProgram = gl.createProgram();
    gl.attachShader(shaderProgram, vertexShader);
    gl.attachShader(shaderProgram, fragmentShader);
    gl.linkProgram(shaderProgram);
    // check for linking errors
    gl.getProgramiv(shaderProgram, gl.LINK_STATUS, &success);
    if (success == 0) {
        gl.getProgramInfoLog(shaderProgram, 512, null, &infoLog);
        std.log.err("ERROR::SHADER::PROGRAM::LINK_FAILED\n{s}", .{infoLog});
        std.process.exit(3);
    }
    gl.deleteShader(vertexShader);
    gl.deleteShader(fragmentShader);
    defer gl.deleteProgram(shaderProgram);

    // set up vertex data (and buffer(s)) and configure vertex attributes
    const vertices = [_]f32{
        // 0.5, 0.5, 0.0, // top right
        // 0.5, -0.5, 0.0, // bottom right
        // -0.5, 0.5, 0.0, // top left
        0.0, 0.0, 0.0,
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
    };
    _ = vertices;
    // const indices = [_]u32{
    //     0, 1, 2, // first triangle
    // };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var arena_allocator = arena.allocator();

    zmesh.init(arena_allocator);
    defer zmesh.deinit();

    var src_positions = std.ArrayList([3]f32).init(arena_allocator);
    var src_indices = std.ArrayList(u32).init(arena_allocator);
    const data = try zmesh.io.parseAndLoadFile("models/minimal.gltf");
    defer zmesh.io.freeData(data);
    try zmesh.io.appendMeshPrimitive(data, 0, 0, &src_indices, &src_positions, null, null, null);
    std.log.debug("pos: {any}\nind: {any}", .{ src_positions.items, src_indices.items });

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
    // gl.bufferData(gl.ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, gl.STATIC_DRAW);
    gl.bufferData(gl.ARRAY_BUFFER, @as(isize, @intCast(src_positions.items.len * @sizeOf([3]f32))), &src_positions.items[0], gl.STATIC_DRAW);

    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    // gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices.len * @sizeOf(u32), &indices, gl.STATIC_DRAW);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @as(isize, @intCast(src_indices.items.len * @sizeOf(u32))), &src_indices.items[0], gl.STATIC_DRAW);

    // note that this is allowed, the call to glVertexAttribPointer registered the VBO as the vertex attribute's
    // bound vertex buffer object so afterwards we can safely unbind
    gl.bindBuffer(gl.ARRAY_BUFFER, 0);

    // you can unbind the VAO afterwards so other VAO calls wont accidentally modify this VAO, but this rarely happens.
    // modifying other VAOs requires a call to glBindVertexArray anyways so we generally don't unbind VAOs (nor VBOs)
    // when its not directly necessary.
    gl.bindVertexArray(0);

    // uncomment this call to draw in wireframe polygons
    // gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);

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
        gl.clear(gl.COLOR_BUFFER_BIT);

        // draw our first triangle
        gl.useProgram(shaderProgram);

        const projection = zm.perspectiveFovRhGl(std.math.degreesToRadians(f32, camera.zoom), @as(f32, @floatFromInt(scr_width_actual)) / @as(f32, @floatFromInt(scr_height_actual)), 0.1, 100.0);
        const view = camera.getViewMatrix();
        gl.uniformMatrix4fv(gl.getUniformLocation(shaderProgram, "projection"), 1, gl.FALSE, &zm.matToArr(projection));
        gl.uniformMatrix4fv(gl.getUniformLocation(shaderProgram, "view"), 1, gl.FALSE, &view);
        gl.uniformMatrix4fv(gl.getUniformLocation(shaderProgram, "model"), 1, gl.FALSE, &zm.matToArr(zm.identity()));

        gl.bindVertexArray(vao);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
        gl.drawElements(gl.TRIANGLES, @as(c_int, @intCast(src_indices.items.len)), gl.UNSIGNED_INT, null);
        // gl.bindVertexArray(0);  // no need to unbind it every time

        // glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        window.swapBuffers();
        glfw.pollEvents();
    }
}

fn framebufferSizeCallback(window: *glfw.Window, width: i32, height: i32) callconv(.C) void {
    _ = window;
    gl.viewport(0, 0, width, height);
    scr_width_actual = @intCast(width);
    scr_height_actual = @intCast(height);
}

fn processInput(window: *glfw.Window) void {
    if (glfw.Window.getKey(window, glfw.Key.escape) == glfw.Action.press) {
        glfw.Window.setShouldClose(window, true);
    }

    if (glfw.Window.getKey(window, glfw.Key.w) == glfw.Action.press) {
        if (glfw.Window.getKey(window, glfw.Key.left_shift) == glfw.Action.press) {
            camera.processMovement(Camera.Movement.up, deltaTime);
        } else {
            camera.processMovement(Camera.Movement.forward, deltaTime);
        }
    }
    if (glfw.Window.getKey(window, glfw.Key.s) == glfw.Action.press) {
        if (glfw.Window.getKey(window, glfw.Key.left_shift) == glfw.Action.press) {
            camera.processMovement(Camera.Movement.down, deltaTime);
        } else {
            camera.processMovement(Camera.Movement.backward, deltaTime);
        }
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

inline fn degToRad(degrees: f32) f32 {
    return degrees * std.math.pi / 180.0;
}
