const std = @import("std");
const gl = @import("zopengl");

pub fn create(allocator: std.mem.Allocator, vertPath: []const u8, fragPath: []const u8) !Shader {
    // retrieve the vertex/fragment source code from filePath
    // ------------------------------------------------------
    const vShaderFile = try std.fs.cwd().openFile(vertPath, .{ .mode = .read_only });
    defer vShaderFile.close();

    const fShaderFile = try std.fs.cwd().openFile(fragPath, .{ .mode = .read_only });
    defer fShaderFile.close();

    var vertexCode = try allocator.alloc(u8, try vShaderFile.getEndPos());
    defer allocator.free(vertexCode);

    var fragmentCode = try allocator.alloc(u8, try fShaderFile.getEndPos());
    defer allocator.free(fragmentCode);

    _ = try vShaderFile.read(vertexCode);
    _ = try fShaderFile.read(fragmentCode);

    // compile shaders
    // ---------------
    const vertex = gl.createShader(gl.VERTEX_SHADER);
    gl.shaderSource(vertex, 1, &vertexCode.ptr, null);
    gl.compileShader(vertex);
    try checkCompilerError(vertex, .vertex);

    const fragment = gl.createShader(gl.FRAGMENT_SHADER);
    gl.shaderSource(fragment, 1, &fragmentCode.ptr, null);
    gl.compileShader(fragment);
    try checkCompilerError(fragment, .fragment);

    const id = gl.createProgram();
    gl.attachShader(id, vertex);
    gl.attachShader(id, fragment);
    gl.linkProgram(id);
    try checkCompilerError(id, .program);

    gl.deleteShader(vertex);
    gl.deleteShader(fragment);

    return Shader{
        .id = id,
    };
}

pub const Shader = struct {
    id: u32,

    pub inline fn use(self: Shader) void {
        gl.useProgram(self.id);
    }

    pub inline fn setBool(self: Shader, name: []const u8, value: bool) void {
        gl.uniform1i(gl.getUniformLocation(self.id, @ptrCast(name)), @as(c_int, value));
    }

    pub inline fn setInt(self: Shader, name: []const u8, value: i32) void {
        gl.uniform1i(gl.getUniformLocation(self.id, @ptrCast(name)), value);
    }

    pub inline fn setFloat(self: Shader, name: []const u8, value: f32) void {
        gl.uniform1f(gl.getUniformLocation(self.id, @ptrCast(name)), value);
    }

    pub inline fn setMatrix4(self: Shader, name: []const u8, transpose: bool, value: [16]f32) void {
        const tpose = if (transpose) gl.TRUE else gl.FALSE;
        gl.uniformMatrix4fv(gl.getUniformLocation(self.id, @ptrCast(name)), 1, tpose, &value);
    }
};

const ErrorType = enum {
    vertex,
    fragment,
    program,
};

fn checkCompilerError(shader: u32, errorType: ErrorType) !void {
    const BUFF_SIZE = 512;
    var success: i32 = 0;
    var infoLog: [BUFF_SIZE]u8 = undefined;
    switch (errorType) {
        .program => {
            gl.getProgramiv(shader, gl.LINK_STATUS, &success);
            if (success == 0) {
                gl.getProgramInfoLog(shader, BUFF_SIZE, null, &infoLog);
                std.log.warn("ERROR::SHADER::PROGRAM::LINKING_FAILED\n{s}\n", .{infoLog});
                return error.Error;
            }
        },
        .vertex, .fragment => {
            gl.getShaderiv(shader, gl.COMPILE_STATUS, &success);
            if (success == 0) {
                gl.getShaderInfoLog(shader, BUFF_SIZE, null, &infoLog);
                std.log.warn("ERROR::SHADER::{}::COMPILATION_FAILED\n{s}\n", .{ errorType, infoLog });
                return error.Error;
            }
        },
    }
}
