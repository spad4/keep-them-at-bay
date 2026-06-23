#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;

out vec4 finalColor;

const vec3 RED = vec3(1, 0, 0.301960784);
const vec3 TARGET = vec3(0.46666666, 0.4980392156862745, 0.576470588);

bool near(float a, float b) {
    
    if (a == b) {
        return true;
    }

    if (a > b && a - 0.005 < b) {
        return true;
    }
    
    if (b > a && b - 0.005 < a) {
        return true;
    }

    return false;
}

void main() {
    vec3 src = texture(texture0, fragTexCoord).rgb;

    vec3 col = src;
    if (near(src.x, TARGET.x) && near(src.y, TARGET.y) && near(src.z, TARGET.z))
        col = RED;
    finalColor = vec4(col, 1.0);
}
