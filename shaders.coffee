semantics =
  VERTEXID : 0
  POSITION : 0
  NORMAL   : 1
  TEXCOORD : 2

shaders = source: {}

shaders.solidmesh =
  keys: ["VS-Scene", "FS-Scene"]
  attribs:
    Position: semantics.POSITION
    Normal: semantics.NORMAL
  uniforms:
    projection: 'projection'
    modelview: 'modelview'
    normalmatrix: 'normalmatrix'
    color: 'color'
    worldOffset: 'worldOffset'

shaders.wireframe =
  keys: ["VS-Wireframe", "FS-Wireframe"]
  attribs:
    Position: semantics.POSITION
  uniforms:
    projection: 'projection'
    modelview: 'modelview'
    depthOffset: 'depthOffset'
    screenOffset: 'screenOffset'
    worldOffset: 'worldOffset'
    color: 'color'
    scale: 'scale'

shaders.vignette =
  keys: ["VS-Vignette", "FS-Vignette"]
  attribs:
    VertexID: semantics.VERTEXID
  uniforms:
    viewport: 'viewport'

shaders.source["VS-Scene"] =
"""
attribute vec4 Position;
attribute vec3 Normal;
uniform mat4 modelview;
uniform mat4 projection;
uniform mat3 normalmatrix;
uniform vec3 worldOffset;
varying vec3 vPosition;
varying vec3 vNormal;
void main(void)
{
    vPosition = Position.xyz + worldOffset;
    vNormal = normalmatrix * Normal;
    vec4 p = vec4(vPosition, 1);
    gl_Position = projection * modelview * p;
}
"""

shaders.source["VS-Wireframe"] =
"""
attribute vec4 Position;
uniform mat4 modelview;
uniform mat4 projection;
uniform float depthOffset;
uniform float scale;
uniform vec2 screenOffset;
uniform vec3 worldOffset;
void main(void)
{
    vec4 p = Position;
    p.xyz *= scale;
    p.xyz += worldOffset;
    gl_Position = projection * modelview * p;
    gl_Position.z += depthOffset;
    gl_Position.xy += screenOffset * 0.15;
}
"""

shaders.source["FS-Wireframe"] =
"""
precision highp float;
precision highp vec3;
uniform vec4 color;
void main()
{
    gl_FragColor = color;
}
"""

shaders.source["FS-Scene"] =
"""
precision highp float;
precision highp vec3;
varying vec3 vNormal;
varying vec3 vPosition;

vec3 LightPosition = vec3(0.25, 0.5, 1.0);
vec3 AmbientMaterial = vec3(0.04, 0.04, 0.04);
vec3 SpecularMaterial = vec3(0.25, 0.25, 0.25);
vec3 FrontMaterial = vec3(0.25, 0.5, 0.75);
vec3 BackMaterial = vec3(0.75, 0.75, 0.7);
float Shininess = 50.0;

uniform vec4 color;

void main()
{
    vec3 N = normalize(vNormal);
    if (!gl_FrontFacing)
        N = -N;

    vec3 L = normalize(LightPosition);
    vec3 Eye = vec3(0, 0, 1);
    vec3 H = normalize(L + Eye);

    float df = max(0.0, dot(N, L));
    float sf = max(0.0, dot(N, H));
    sf = pow(sf, Shininess);

    vec3 P = vPosition;
    vec3 I = normalize(P);
    float cosTheta = abs(dot(I, N));
    float fresnel = 1.0 - clamp(pow(1.0 - cosTheta, 0.125), 0.0, 1.0);

    vec3 mat = !gl_FrontFacing ? FrontMaterial : BackMaterial;
    mat *= color.rgb;
    vec3 lighting = AmbientMaterial + df * mat;
    if (gl_FrontFacing)
        lighting += sf * SpecularMaterial;

    lighting += fresnel;
    gl_FragColor = vec4(lighting,1);
}
"""

shaders.source["VS-Vignette"] =
"""
attribute vec2 VertexID;
void main(void)
{
    vec2 p = 3.0 - 4.0 * VertexID;
    gl_Position = vec4(p, 0, 1);
}
"""

shaders.source["FS-Vignette"] =
"""
precision highp float;
precision highp vec2;

uniform vec2 viewport;
void main()
{
    vec2 c = gl_FragCoord.xy / viewport;
    float f = 1.0 - 0.5 * pow(distance(c, vec2(0.5)), 1.5);
    gl_FragColor = vec4(f, f, f, 1);
    gl_FragColor.rgb *= vec3(0.867, 0.18, 0.447); // Hot Pink!
}
"""
