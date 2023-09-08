const std = @import("std");

const glfw = @import("zglfw");
const gl = @import("zopengl");
const zm = @import("zmath");
const zmesh = @import("zmesh");

const shader = @import("shader.zig");
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

const VERT_SHADER = "shaders/lpo_01_gltf.vert";
const FRAG_SHADER = "shaders/lpo_01_gltf.frag";

const GLTF_FILE = "models/asteroids.gltf";

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

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var arena_allocator = arena.allocator();

    const myShader = try shader.create(allocator, VERT_SHADER, FRAG_SHADER);

    zmesh.init(arena_allocator);
    defer zmesh.deinit();

    var src_positions = std.ArrayList([3]f32).init(arena_allocator);
    var src_indices = std.ArrayList(u32).init(arena_allocator);
    const data = try zmesh.io.parseAndLoadFile(GLTF_FILE);
    defer zmesh.io.freeData(data);
    try zmesh.io.appendMeshPrimitive(data, 0, 0, &src_indices, &src_positions, null, null, null);

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
    gl.bufferData(gl.ARRAY_BUFFER, @as(isize, @intCast(src_positions.items.len * @sizeOf([3]f32))), &src_positions.items[0], gl.STATIC_DRAW);

    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @as(isize, @intCast(src_indices.items.len * @sizeOf(u32))), &src_indices.items[0], gl.STATIC_DRAW);

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
        myShader.use();

        const projection = zm.perspectiveFovRhGl(std.math.degreesToRadians(f32, camera.zoom), @as(f32, @floatFromInt(scr_width_actual)) / @as(f32, @floatFromInt(scr_height_actual)), 0.1, 100.0);
        const view = camera.getViewMatrix();
        const model = zm.rotationY(currentFrame);
        myShader.setMatrix4("projection", false, zm.matToArr(projection));
        myShader.setMatrix4("view", false, view);
        myShader.setMatrix4("model", false, zm.matToArr(model));

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
