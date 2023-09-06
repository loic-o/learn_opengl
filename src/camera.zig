const std = @import("std");
const zm = @import("zmath");

const Camera = @This();

const dToR = std.math.degreesToRadians;
const sin = std.math.sin;
const cos = std.math.cos;

pub const MoveMove = struct {
    deltaX: f32,
    deltaY: f32,
};

pub const Movement = union(enum) {
    forward: void,
    backward: void,
    up: void,
    down: void,
    left: void,
    right: void,
    rotate: MoveMove,
    zoom: f32,
};

position: zm.Vec,
up: zm.Vec,
yaw: f32,
pitch: f32,
front: zm.Vec,
movement_speed: f32,
mouse_sensitivity: f32,
zoom: f32,

pub fn create(position: zm.Vec, up: zm.Vec, yaw: f32, pitch: f32) Camera {
    var cam = Camera{
        .position = position,
        .up = up,
        .yaw = yaw,
        .pitch = pitch,
        .front = zm.f32x4(0.0, 0.0, -1.0, 0.0),
        .movement_speed = 2.5,
        .mouse_sensitivity = 0.1,
        .zoom = 45.0,
    };
    cam.updateCameraVectors();
    return cam;
}

pub fn getViewMatrix(self: Camera) [16]f32 {
    const mat = zm.lookAtRh(self.position, self.position + self.front, self.up);
    return zm.matToArr(mat);
}

pub fn processMovement(self: *Camera, movement: Movement, delta_time: f32) void {
    var velocity = zm.f32x4s(self.movement_speed * delta_time);
    switch (movement) {
        .forward => {
            self.position += self.front * velocity;
        },
        .backward => {
            self.position -= self.front * velocity;
        },
        .left => {
            self.position -= zm.normalize3(zm.cross3(self.front, self.up)) * velocity;
        },
        .right => {
            self.position += zm.normalize3(zm.cross3(self.front, self.up)) * velocity;
        },
        .up => {
            self.position += self.up * velocity;
        },
        .down => {
            self.position -= self.up * velocity;
        },
        .rotate => |offsets| {
            self.yaw += offsets.deltaX * self.mouse_sensitivity;
            self.pitch += offsets.deltaY * self.mouse_sensitivity;
            if (self.pitch > 89.0) {
                self.pitch = 89.0;
            }
            if (self.pitch < -89.0) {
                self.pitch = -89.0;
            }
            self.updateCameraVectors();
        },
        .zoom => |offset| {
            self.zoom -= offset;
            if (self.zoom < 1.0) {
                self.zoom = 1.0;
            }
            if (self.zoom > 45.0) {
                self.zoom = 45.0;
            }
        },
    }
}

fn updateCameraVectors(self: *Camera) void {
    var front: zm.Vec = .{ 0.0, 0.0, 0.0, 0.0 };
    front[0] = cos(dToR(f32, self.yaw)) * cos(dToR(f32, self.pitch));
    front[1] = sin(dToR(f32, self.pitch));
    front[2] = sin(dToR(f32, self.yaw)) * cos(dToR(f32, self.pitch));
    self.front = zm.normalize3(front);
}
