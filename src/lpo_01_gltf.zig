const std = @import("std");

const glfw = @import("zglfw");
const gl = @import("zopengl");
const zm = @import("zmath");
const stbi = @import("zstbi");
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
const TEXTURE_FILE = "textures/resurrect64_lpo_2x64.png";

const Vertex = struct {
    position: [3]f32,
    normal: [3]f32,
    texCoords: [2]f32,
};

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

    gl.enable(gl.DEPTH_TEST);
    gl.enable(gl.CULL_FACE);
    gl.cullFace(gl.BACK);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var arena_allocator = arena.allocator();

    // initialize stb_image lib
    stbi.init(allocator);
    defer stbi.deinit();
    // stbi.setFlipVerticallyOnLoad(true);

    // initialise the zmesh library
    zmesh.init(arena_allocator);
    defer zmesh.deinit();

    const myShader = try shader.create(allocator, VERT_SHADER, FRAG_SHADER);

    var src_indices = std.ArrayList(u32).init(arena_allocator);
    var src_positions = std.ArrayList([3]f32).init(arena_allocator);
    var src_normals = std.ArrayList([3]f32).init(arena_allocator);
    var src_texcoords = std.ArrayList([2]f32).init(arena_allocator);
    const data = try zmesh.io.parseAndLoadFile(GLTF_FILE);
    defer zmesh.io.freeData(data);
    try zmesh.io.appendMeshPrimitive(data, 0, 0, &src_indices, &src_positions, &src_normals, &src_texcoords, null);

    var src_vertices = try std.ArrayList(Vertex).initCapacity(arena_allocator, src_positions.items.len);
    for (src_positions.items, 0..) |_, i| {
        src_vertices.appendAssumeCapacity(Vertex{
            .position = src_positions.items[i],
            .normal = src_normals.items[i],
            .texCoords = src_texcoords.items[i],
            // .texCoords = .{ 0.438, 0.933 },  // values as i see them in blender
        });
    }

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
    gl.bufferData(gl.ARRAY_BUFFER, @as(isize, @intCast(src_vertices.items.len * @sizeOf(Vertex))), &src_vertices.items[0], gl.STATIC_DRAW);

    // position attribute
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), null);
    gl.enableVertexAttribArray(0);
    // normal attribute
    gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @ptrFromInt(3 * @sizeOf(f32)));
    gl.enableVertexAttribArray(1);
    // texture coord attribute
    gl.vertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @ptrFromInt(6 * @sizeOf(f32)));
    gl.enableVertexAttribArray(2);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @as(isize, @intCast(src_indices.items.len * @sizeOf(u32))), &src_indices.items[0], gl.STATIC_DRAW);

    // const diffuseMap = try loadTextureEx(TEXTURE_FILE, false, false, gl.NEAREST, gl.NEAREST);
    // *****
    std.debug.assert(data.images != null);
    std.debug.assert(data.images.?[0].buffer_view != null);
    var img_buff_view = data.images.?[0].buffer_view.?;
    const buffer_data_ptr = @as([*]const u8, @ptrCast(img_buff_view.buffer.data));
    const img_data = buffer_data_ptr[img_buff_view.offset..][0..img_buff_view.size];
    var image = try stbi.Image.loadFromMemory(img_data, 0);
    defer image.deinit();
    //
    var diffuseMap: u32 = undefined;
    gl.genTextures(1, &diffuseMap);
    gl.bindTexture(gl.TEXTURE_2D, diffuseMap);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, @intCast(image.width), @intCast(image.height), 0, gl.RGBA, gl.UNSIGNED_BYTE, @ptrCast(image.data));
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

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
        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        myShader.use();

        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, diffuseMap);
        myShader.setInt("diffuseTexture", 0);

        const projection = zm.perspectiveFovRhGl(std.math.degreesToRadians(f32, camera.zoom), @as(f32, @floatFromInt(scr_width_actual)) / @as(f32, @floatFromInt(scr_height_actual)), 0.1, 100.0);
        const view = camera.getViewMatrix();
        const model = zm.rotationY(currentFrame);
        myShader.setMatrix4("projection", false, zm.matToArr(projection));
        myShader.setMatrix4("view", false, view);
        myShader.setMatrix4("model", false, zm.matToArr(model));
        myShader.setMatrix4("modelInvTranspose", false, zm.matToArr(zm.transpose(zm.inverse(model))));

        myShader.setVec3("light.direction", .{ 1.0, -1.0, -1.0 });
        myShader.setVec3("light.ambient", .{ 0.2, 0.2, 0.2 });
        myShader.setVec3("light.diffuse", .{ 0.5, 0.5, 0.5 });

        gl.bindVertexArray(vao);
        // gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
        gl.drawElements(gl.TRIANGLES, @as(c_int, @intCast(src_indices.items.len)), gl.UNSIGNED_INT, null);

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

fn loadTextureEx(path: []const u8, flip: bool, mipmap: bool, comptime minFilter: comptime_int, comptime magFilter: comptime_int) !u32 {
    var textureID: u32 = undefined;
    gl.genTextures(1, &textureID);

    if (flip) {
        stbi.setFlipVerticallyOnLoad(true);
    } else {
        stbi.setFlipVerticallyOnLoad(false);
    }
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
    if (mipmap) {
        gl.generateMipmap(gl.TEXTURE_2D);
    }

    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, minFilter);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, magFilter);

    return textureID;
}

fn loadTexture(path: []const u8) !u32 {
    return try loadTextureEx(path, true, true, gl.LINEAR_MIPMAP_LINEAR, gl.LINEAR);
}
