// Generated by CoffeeScript 1.3.1
(function() {
  var aabb, root, utility;

  root = typeof exports !== "undefined" && exports !== null ? exports : this;

  root.utility = {};

  utility = root.utility;

  utility.clone = function(obj) {
    var key, newInstance;
    if (!(obj != null) || typeof obj !== 'object') {
      return obj;
    }
    newInstance = new obj.constructor();
    for (key in obj) {
      newInstance[key] = utility.clone(obj[key]);
    }
    return newInstance;
  };

  utility.aabb = aabb = (function() {

    aabb.name = 'aabb';

    function aabb(left, top, right, bottom) {
      this.left = left;
      this.top = top;
      this.right = right;
      this.bottom = bottom;
    }

    aabb.createFromCorner = function(leftTop, size) {
      var bottom, left, right, top, _ref;
      left = leftTop[0], top = leftTop[1];
      _ref = [left + size[0], top + size[1]], right = _ref[0], bottom = _ref[1];
      return new aabb(left, top, right, bottom);
    };

    aabb.createFromCenter = function(center, size) {
      var bottom, hh, hw, left, right, top, _ref, _ref1, _ref2;
      _ref = [size[0] / 2, size[1] / 2], hw = _ref[0], hh = _ref[1];
      _ref1 = [center[0] - hw, center[1] - hh], left = _ref1[0], top = _ref1[1];
      _ref2 = [center[0] + hw, center[1] + hh], right = _ref2[0], bottom = _ref2[1];
      return new aabb(left, top, right, bottom);
    };

    aabb.prototype.setFromCenter = function(center, size) {
      var hh, hw, _ref, _ref1, _ref2;
      _ref = [size[0] / 2, size[1] / 2], hw = _ref[0], hh = _ref[1];
      _ref1 = [center[0] - hw, center[1] - hh], this.left = _ref1[0], this.top = _ref1[1];
      return _ref2 = [center[0] + hw, center[1] + hh], this.right = _ref2[0], this.bottom = _ref2[1], _ref2;
    };

    aabb.prototype.contains = function(x, y) {
      return x >= this.left && x < this.right && y >= this.top && y < this.bottom;
    };

    aabb.prototype.width = function() {
      return this.right - this.left;
    };

    aabb.prototype.height = function() {
      return this.bottom - this.top;
    };

    aabb.prototype.centerx = function() {
      return (this.left + this.right) / 2;
    };

    aabb.prototype.centery = function() {
      return (this.bottom + this.top) / 2;
    };

    aabb.prototype.size = function() {
      return [this.width(), this.height()];
    };

    aabb.prototype.viewport = function(gl) {
      return gl.viewport(this.left, this.top, this.width(), this.height());
    };

    aabb.prototype.translated = function(x, y) {
      return new aabb(this.left + x, this.top + y, this.right + x, this.bottom + y);
    };

    aabb.intersect = function(a, b) {
      return new aabb(Math.max(a.left, b.left), Math.max(a.top, b.top), Math.min(a.right, b.right), Math.min(a.bottom, b.bottom));
    };

    aabb.prototype.degenerate = function() {
      return this.left >= this.right || this.top >= this.bottom;
    };

    aabb.prototype.inflate = function(delta, deltay) {
      this.left -= delta;
      this.right += delta;
      if (deltay != null) {
        delta = deltay;
      }
      this.top -= delta;
      return this.bottom += delta;
    };

    aabb.prototype.deflate = function(delta, deltay) {
      this.left += delta;
      this.right -= delta;
      if (deltay != null) {
        delta = deltay;
      }
      this.top += delta;
      return this.bottom -= delta;
    };

    aabb.lerp = function(a, b, t) {
      var h, w, x, y;
      w = (1 - t) * a.width() + t * b.width();
      h = (1 - t) * a.height() + t * b.height();
      x = (1 - t) * a.centerx() + t * b.centerx();
      y = (1 - t) * a.centery() + t * b.centery();
      return aabb.createFromCenter([x, y], [w, h]);
    };

    aabb.cropMatrix = function(cropRegion, entireViewport) {
      var m, sx, sy, tx, ty;
      sx = entireViewport.width() / cropRegion.width();
      sy = entireViewport.height() / cropRegion.height();
      tx = 2 * (entireViewport.width() + 2 * (entireViewport.left - cropRegion.centerx())) / cropRegion.width();
      ty = 2 * (entireViewport.height() + 2 * (entireViewport.top - cropRegion.centery())) / cropRegion.height();
      m = mat4.create();
      m[0] = sx;
      m[1] = 0;
      m[2] = 0;
      m[3] = tx;
      m[4] = 0;
      m[5] = sy;
      m[6] = 0;
      m[7] = ty;
      m[8] = 0;
      m[9] = 0;
      m[10] = 1;
      m[11] = 0;
      m[12] = 0;
      m[13] = 0;
      m[14] = 0;
      m[15] = 1;
      return mat4.transpose(m);
    };

    return aabb;

  })();

}).call(this);