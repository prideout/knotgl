root = exports ? this

# Vertex Attribute Semantics
root.POSITION = 0
root.NORMAL = 1

# Global Constants
Slices = 128
root.Stacks = 128
TWOPI = 2 * Math.PI
EPSILON = 0.0001

# Various Globals
theta = 0
projection = mat4.create()
modelview = mat4.create()
normalMatrix = mat3.create()

# Shortcuts
[sin, cos, pow, abs] = [Math.sin, Math.cos, Math.pow, Math.abs]

# Main Render Loop
Render = ->
  [gl, vbo] = [root.gl, root.vbo]
  gl.clearColor(0.5,0.5,0.5,1)
  gl.clear(gl.COLOR_BUFFER_BIT)
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo)
  gl.enableVertexAttribArray(root.POSITION)
  gl.vertexAttribPointer(root.POSITION, 3, gl.FLOAT, false, stride = 12, 0)
  gl.drawArrays(gl.TRIANGLES, 0, vbo.vertCount)
  if gl.getError() != gl.NO_ERROR
    glerr("OpenGL error")

# Create VBOs
InitBuffers = ->
  gl = root.gl
  vbo = gl.createBuffer()
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo)
  vertices = [
    0.0,  1.0,  0.0
    -0.2, -1.0, 0.0
    1.0, -1.0,  0.0
  ]
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(vertices), gl.STATIC_DRAW)
  vbo.vertCount = 3

  rawBuffer = new Float32Array(Slices * root.Stacks * 8)
  [slice, i] = [-1, 0]
  BmA = CmA = n = vec3.create()
  while ++slice < Slices
    [v, stack] = [slice * TWOPI / Slices, -1]
    while ++stack < root.Stacks
      u = stack * TWOPI / root.Stacks
      A = p = MobiusTube(u, v)
      B = MobiusTube(u + EPSILON, v)
      C = MobiusTube(u, v + EPSILON)
      vec3.subtract(B,A,BmA)
      vec3.subtract(C,A,CmA)
      vec3.cross(BmA,CmA,n)
      vec3.normalize(n,n)
      [vertex, i] = [rawBuffer.subarray(i, i+8), i+8]
      vertex[0] = p.x
      vertex[1] = p.y
      vertex[2] = p.z
      vertex[3] = n.x
      vertex[4] = n.y
      vertex[5] = n.z
      vertex[6] = u
      vertex[7] = v

  glinfo("#{i} floats generated from #{Slices} slices and #{Stacks} stacks.")

  ###
    for (int slice = 0; slice < Slices; slice++) {
        float v = slice * TwoPi / slices;
        for (int stack = 0; stack < root.Stacks; stack++) {
            float u = stack * TwoPi / stacks;

            float alpha = 0.8;   // 0.15 for horn, 1.0 for snail
            float beta = 1;
            float gamma = 0.1; // tightness
            float n = 2;       // twists

            Point3 p = ParametricHorn(u, v, alpha, beta, gamma, n);
            *position++ = p.x;
            *position++ = p.y;
            *position++ = p.z;
        }
    }
  ###
  root.vbo = vbo

sgn = (x) -> if x > 0 then +1 else (if x < 0 then -1 else 0)

# Parametric Function for the Mobius Tube Surface
MobiusTube = (u, v) ->
  [R, n] = [1.5, 3]
  x = (1.0*R + 0.125*sin(u/2)*pow(abs(sin(v)), 2/n)*sgn(sin(v)) + 0.5*cos(u/2)*pow(abs(cos(v)), 2/n)*sgn(cos(v)))*cos(u)
  y = (1.0*R + 0.125*sin(u/2)*pow(abs(sin(v)), 2/n)*sgn(sin(v)) + 0.5*cos(u/2)*pow(abs(cos(v)), 2/n)*sgn(cos(v)))*sin(u)
  z = -0.5*sin(u/2)*pow(abs(cos(v)), 2/n)*sgn(cos(v)) + 0.125*cos(u/2)*pow(abs(sin(v)), 2/n)*sgn(sin(v))
  vec3.create([x, y, z])

# Initialization Function
root.AppInit = ->
  canvas = $("canvas")
  w = parseInt(canvas.css('width'))
  h = parseInt(canvas.css('height'))
  canvas.css('margin-left', -w/2)
  canvas.css('margin-top', -h/2)
  root.gl = gl = canvas.get(0).getContext("experimental-webgl", { antialias: true } )

  if not gl.getExtension("OES_texture_float")
    glerr("Your browser does not support floating-point textures.")

  InitBuffers()

  # Create depth program
  vertexShader = getShader(gl, "VS-Scene")
  fragmentShader = getShader(gl, "FS-Depth")
  depthProgram = gl.createProgram()
  gl.attachShader(depthProgram, vertexShader)
  gl.attachShader(depthProgram, fragmentShader)
  gl.bindAttribLocation(depthProgram, root.POSITION, "Position")
  gl.bindAttribLocation(depthProgram, root.NORMAL, "Normal")
  gl.linkProgram(depthProgram)
  if not gl.getProgramParameter(depthProgram, gl.LINK_STATUS)
    glerr('Could not link shaders')

  gl.useProgram(depthProgram)
  depthProgram.projectionUniform = gl.getUniformLocation(depthProgram, "Projection")
  depthProgram.modelviewUniform = gl.getUniformLocation(depthProgram, "Modelview")
  depthProgram.normalMatrixUniform = gl.getUniformLocation(depthProgram, "NormalMatrix")

  gl.disable(gl.CULL_FACE)
  gl.disable(gl.DEPTH_TEST)

  canvas.width = canvas.clientWidth
  canvas.height = canvas.clientHeight
  root.gl = gl
  setInterval(Render, 15)
