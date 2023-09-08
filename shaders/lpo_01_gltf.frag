#version 330 core

struct DirLight {
    vec3 direction;
    vec3 ambient;
    vec3 diffuse;
};

vec3 calcDirLight(DirLight light, vec3 normal);

out vec4 FragColor;

in vec3 FragPos;
in vec3 Normal;
in vec2 TexCoord;

uniform DirLight light;
uniform sampler2D diffuseTexture;

void main() {
    vec3 result = calcDirLight(light, Normal);
    // vec3 result = vec3(texture(diffuseTexture, TexCoord));
    FragColor = vec4(result, 1.0f);
}

vec3 calcDirLight(DirLight light, vec3 normal) {
    // ambient
    vec3 ambient = light.ambient * vec3(texture(diffuseTexture, TexCoord));

    // diffuse
    vec3 norm = normalize(Normal);
    vec3 lightDir = normalize(-light.direction);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = light.diffuse * diff * vec3(texture(diffuseTexture, TexCoord));

    vec3 result = ambient + diffuse;

    return result;
}

