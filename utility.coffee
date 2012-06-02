
COLORS =
    black: [0,0,0]
    darkgray:  [.1,.1,.1]

glerr = (msg) -> $.gritter.add title: 'WebGL Error', text: msg
toast = (msg) -> $.gritter.add title: 'Notice', text: msg

utility = {}

# Deep copy (why doesn't JS have this natively?)
# Caution: doesn't seem to work with glmatrix types in Firefox, but works in Chrome.
utility.clone = (obj) ->
  if not obj? or typeof obj isnt 'object'
    return obj
  newInstance = new obj.constructor()
  for key of obj
    newInstance[key] = utility.clone obj[key]
  return newInstance

# Axis-aligned bounding box.
# Just like CSS, Y increases downwards.
# Left-top boundary is inclusive, right-bottom is exclusive.
utility.aabb = class aabb

  constructor: (@left, @top, @right, @bottom) ->
  contains: (x,y) -> x >= @left and x < @right and y >= @top and y < @bottom
  width: -> @right - @left
  height: -> @bottom - @top
  centerx: -> (@left + @right) / 2
  centery: -> (@bottom + @top) / 2
  size: -> [@width(), @height()]
  viewport: (gl) -> gl.viewport @left, @top, @width(), @height()
  translated: (x,y) -> new aabb @left+x,@top+y,@right+x,@bottom+y
  degenerate: -> @left >= @right or @top >= @bottom

  setFromCenter: (center, size) ->
    [hw, hh] = [size[0]/2, size[1]/2]
    [@left, @top] = [center[0] - hw, center[1] - hh]
    [@right, @bottom] = [center[0] + hw, center[1] + hh]

  inflate: (delta, deltay) ->
    @left -= delta
    @right += delta
    delta = deltay if deltay?
    @top -= delta
    @bottom += delta

  deflate: (delta, deltay) ->
    @left += delta
    @right -= delta
    delta = deltay if deltay?
    @top += delta
    @bottom -= delta

  @createFromCorner: (leftTop, size) ->
    [left, top] = leftTop
    [right, bottom] = [left + size[0], top + size[1]]
    new aabb left, top, right, bottom

  @createFromCenter: (center, size) ->
    [hw, hh] = [size[0]/2, size[1]/2]
    [left, top] = [center[0] - hw, center[1] - hh]
    [right, bottom] = [center[0] + hw, center[1] + hh]
    new aabb left, top, right, bottom

  @intersect: (a, b) -> new aabb(
    Math.max(a.left,b.left),
    Math.max(a.top,b.top),
    Math.min(a.right,b.right),
    Math.min(a.bottom,b.bottom))
  
  @lerp: (a, b, t) ->
    w = (1-t) * a.width()  + t * b.width()
    h = (1-t) * a.height() + t * b.height()
    x = (1-t) * a.centerx() + t * b.centerx()
    y = (1-t) * a.centery() + t * b.centery()
    aabb.createFromCenter [x,y], [w,h]

  # Generates a mat4 that can be multiplied with a projection matrix
  # to "crop" the viewing frustum.
  # See bottom of:
  #   http://github.prideout.net/barrel-distortion/
  # TODO the code can be vastly simplified with simple algebra
  @cropMatrix: (cropRegion, entireViewport) ->
    sx = entireViewport.width() / cropRegion.width()
    sy = entireViewport.height() / cropRegion.height()
    tx = 2*(entireViewport.width() + 2 * (entireViewport.left - cropRegion.centerx())) / cropRegion.width()
    ty = 2*(entireViewport.height() + 2 * (entireViewport.top - cropRegion.centery())) / cropRegion.height()
    m = mat4.create()
    m[0] = sx; m[1] = 0; m[2] = 0; m[3] = tx;
    m[4] = 0; m[5] = sy; m[6] = 0; m[7] = ty;
    m[8] = 0; m[9] = 0; m[10] = 1; m[11] = 0;
    m[12] = 0; m[13] = 0; m[14] = 0; m[15] = 1;
    mat4.transpose(m)

