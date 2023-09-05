#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec3 FragPos;
out vec3 Normal;

void main() {
    gl_Position = projection * view * model * vec4(aPos, 1.0);
    FragPos = vec3(model * vec4(aPos, 1.0));
    // inverte is expense - typically we wouldn't want to do this here for
    // each vertex, rather we would compute this in code right next to the
    // model matrix and pass it in as a uniform (just like the model matrix)
    Normal = mat3(transpose(inverse(model))) * aNormal;
}

