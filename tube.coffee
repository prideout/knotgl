root = exports ? this

# Global Constants
TWOPI = 2 * Math.PI

# Aliases and Monkey Patches
[sin, cos, pow, abs] = (Math[f] for f in "sin cos pow abs".split(' '))
dot = vec3.dot
sgn = (x) -> if x > 0 then +1 else (if x < 0 then -1 else 0)
vec3.perp = (u, dest) ->
  v = vec3.create([1,0,0])
  vec3.cross(u,v,dest)
  e = dot(dest,dest)
  if e < 0.01
    vec3.set(v,[0,1,0])
    vec3.cross(u,v,dest)
  vec3.normalize(dest)

class TubeGenerator
  constructor: () ->
    @globalScale = 0.15
    @bezierSlices = 3
    @tangentSmoothness = 3
    @polygonSides = 8
    @radius = 0.1

root.TubeGenerator = TubeGenerator

# Returns a list of knot paths
root.GetLinkPaths = (links, slices) ->
  root.GetKnotPath(link, slices) for link in links

# Evaluate a Bezier function for smooth interpolation
root.GetKnotPath = (data, slices) ->
  globalScale = 0.15
  rawBuffer = new Float32Array(data.length * slices + 3)
  [i,j] = [0,0]
  while i < data.length+3
    r = ((i+n)%data.length for n in [0,2,3,5,6,8])
    a = data[r[0]..r[1]]
    b = data[r[2]..r[3]]
    c = data[r[4]..r[5]]
    v1 = vec3.create(a)
    v4 = vec3.create(b)
    vec3.lerp(v1, b, 0.5)
    vec3.lerp(v4, c, 0.5)
    v2 = vec3.create(v1)
    v3 = vec3.create(v4)
    vec3.lerp(v2, b, 1/3)
    vec3.lerp(v3, b, 1/3)
    t = dt = 1 / (slices+1)
    for slice in [0...slices]
      tt = 1-t
      c = [tt*tt*tt,3*tt*tt*t,3*tt*t*t,t*t*t]
      p = (vec3.create(v) for v in [v1,v2,v3,v4])
      vec3.scale(p[ii],c[ii]) for ii in [0...4]
      p = p.reduce (a,b) -> vec3.add(a,b)
      vec3.scale(p, globalScale)
      rawBuffer.set(p, j)
      j += 3
      if j >= rawBuffer.length
        console.log "Bezier: generated #{j/3} points from #{data.length/3} control points."
        return rawBuffer
      t += dt
    i += 3

# Sweep a n-sided polygon along the given centerline
# Repeat the vertex along the seam to allow nice texture coords.
root.GenerateTube = (centerline, n) ->
  frames = GenerateFrames(centerline, smoothing = 5)
  count = centerline.length / 3
  mesh = new Float32Array(count * (n+1) * 3)
  [i, m] = [0, 0]
  p = vec3.create()
  r = 0.1
  while i < count
      v = 0
      basis = (frames[C].subarray(i*3,i*3+3) for C in [0..2])
      basis = ((B[C] for C in [0..2]) for B in basis)
      basis = (basis.reduce (A,B) -> A.concat(B))
      basis = mat3.create(basis)
      theta = 0
      dtheta = TWOPI / n
      while v < n+1
        x = r*cos(theta)
        y = r*sin(theta)
        z = 0
        mat3.multiplyVec3(basis, [x,y,z], p)
        p[0] += centerline[i*3+0] # TODO clean this
        p[1] += centerline[i*3+1]
        p[2] += centerline[i*3+2]
        #console.log "GenerateTube: P = #{vec3.str(p)}"
        mesh.set(p, m)
        [m, v, theta] = [m+3,v+1,theta+dtheta]
      i++
  console.log "GenerateTube: generated #{m} vertices from a centerline with #{count} nodes."
  mesh

# Generate reasonable orthonormal basis vectors for curve in R3
# See "Computation of Rotation Minimizing Frame" by Wang and Jüttler
GenerateFrames = (centerline, smoothing = 0) ->
  count = centerline.length / 3
  frameR = new Float32Array(count * 3)
  frameS = new Float32Array(count * 3)
  frameT = new Float32Array(count * 3)

  # Obtain unit-length tangent vectors
  i = -1
  while ++i < count
    j = (i+1+smoothing) % (count-1)
    xi = centerline.subarray(i*3, i*3+3)
    xj = centerline.subarray(j*3, j*3+3)
    ti = frameT.subarray(i*3, i*3+3)
    vec3.direction(xi, xj, ti)

  # Allocate some temporaries for vector math
  [r0,  s0,  t0]  = (vec3.create() for n in [0..2])
  [rj,  sj,  tj]  = (vec3.create() for n in [0..2])

  # Create a somewhat-arbitrary initial frame (r0, s0, t0)
  vec3.set(frameT.subarray(0, 3), t0)
  vec3.perp(t0, r0)
  vec3.cross(t0, r0, s0)
  vec3.normalize(r0)
  vec3.normalize(s0)
  vec3.set(r0, frameR.subarray(0, 3))
  vec3.set(s0, frameS.subarray(0, 3))

  # Use parallel transport to sweep the frame
  [i,j] = [0,1]
  [ri, si, ti] = [r0, s0, t0]
  while i < count
    j = (i+1) % count
    xi = centerline.subarray(i*3, i*3+3)
    xj = centerline.subarray(j*3, j*3+3)
    ti = frameT.subarray(i*3, i*3+3)
    tj = frameT.subarray(j*3, j*3+3)
    vec3.cross(tj, ri, sj)
    vec3.normalize(sj)
    vec3.cross(sj, tj, rj)
    vec3.set(rj, frameR.subarray(j*3, j*3+3))
    vec3.set(sj, frameS.subarray(j*3, j*3+3))
    ++i

  # Return the basis columns
  [frameR, frameS, frameT]
