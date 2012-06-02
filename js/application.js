// Generated by CoffeeScript 1.3.1
(function() {
  var CurrentSizes, assignEventHandlers, collapsing, expanding, exportScreenshot, getPagePosition, layout, root, tick, updateNumeralSizes, updateSwipeAnimation;

  root = typeof exports !== "undefined" && exports !== null ? exports : this;

  root.pageIndex = 1;

  root.pan = {
    x: 0
  };

  root.mouse = {
    position: {
      x: -1,
      y: -1
    },
    within: false,
    hot: false,
    moved: false
  };

  CurrentSizes = utility.clone(metadata.ExpandedSizes);

  collapsing = expanding = false;

  $(function() {
    var c, gl, height, width;
    c = $('canvas').get(0);
    gl = c.getContext('experimental-webgl', {
      antialias: true
    });
    if (!gl.getExtension('OES_texture_float')) {
      glerr('Your browser does not support floating-point textures.');
    }
    if (!gl.getExtension('OES_standard_derivatives')) {
      glerr('Your browser does not support GLSL derivatives.');
    }
    width = parseInt($('#overlay').css('width'));
    height = parseInt($('#overlay').css('height'));
    root.renderer = new root.Renderer(gl, width, height);
    layout();
    assignEventHandlers();
    return window.requestAnimationFrame(tick, c);
  });

  root.AnimateNumerals = function() {
    var collapse, duration, expand;
    if (collapsing || expanding) {
      return;
    }
    duration = 0.25 * root.renderer.transitionMilliseconds;
    collapse = new TWEEN.Tween(CurrentSizes).to(metadata.CollapsedSizes, duration).easing(TWEEN.Easing.Quintic.In).onUpdate(updateNumeralSizes).onComplete(function() {
      return collapsing = false;
    });
    expand = new TWEEN.Tween(CurrentSizes).to(metadata.ExpandedSizes, duration).easing(TWEEN.Easing.Quintic.In).onUpdate(updateNumeralSizes).onComplete(function() {
      return expanding = false;
    });
    collapsing = expanding = true;
    collapse.chain(expand);
    return collapse.start();
  };

  root.SwipePane = function() {
    var panTarget, swipeDuration;
    if (root.swipeTween != null) {
      return;
    }
    root.pageIndex = 1 - root.pageIndex;
    panTarget = getPagePosition(root.pageIndex);
    swipeDuration = 1000;
    root.swipeTween = new TWEEN.Tween(root.pan).to({
      x: panTarget
    }, swipeDuration).easing(TWEEN.Easing.Bounce.Out).onUpdate(updateSwipeAnimation).onComplete(function() {
      return root.swipeTween = null;
    });
    return root.swipeTween.start();
  };

  tick = function() {
    var cursor, h, highlightRow, labels, r, top;
    r = root.renderer;
    window.requestAnimationFrame(tick, $("canvas").get(0));
    TWEEN.update();
    if (!collapsing) {
      labels = r.getCurrentLinkInfo();
      $('#crossings').text(labels.crossings);
      $('#subscript').text(labels.index);
      $('#superscript').text(labels.numComponents);
    }
    if (root.pageIndex === 0) {
      if (root.mouse.moved) {
        h = r.height / r.links.length;
        highlightRow = Math.floor(root.mouse.position.y / h);
        if (highlightRow >= r.links.length) {
          highlightRow = null;
        }
        if ($('#grasshopper').is(':hover')) {
          highlightRow = -1;
        }
        r.highlightRow = highlightRow;
      }
      $('#highlight-row').css('visibility', 'visible');
      top = r.highlightRow * r.height / r.links.length;
      $('#highlight-row').css('top', top);
    }
    cursor = root.renderer.hotMouse || root.mouse.hot || root.pageIndex === 0 ? 'pointer' : '';
    $('#rightpage').css({
      'cursor': cursor
    });
    $('#leftpage').css({
      'cursor': cursor
    });
    if (r.ready) {
      r.render();
    }
    return root.mouse.moved = false;
  };

  assignEventHandlers = function() {
    $(window).resize(function() {
      return layout();
    });
    $(document).keydown(function(e) {
      if (e.keyCode === 38) {
        root.renderer.moveSelection(0, -1);
      }
      if (e.keyCode === 40) {
        root.renderer.moveSelection(0, +1);
      }
      if (e.keyCode === 37) {
        root.renderer.moveSelection(-1, 0);
      }
      if (e.keyCode === 39) {
        root.renderer.moveSelection(+1, 0);
      }
      if (e.keyCode === 32) {
        root.SwipePane();
      }
      if (e.keyCode === 83) {
        return exportScreenshot();
      }
    });
    $('.arrow').mouseover(function() {
      $(this).css('color', '#385fa2');
      return root.mouse.hot = true;
    });
    $('.arrow').mouseout(function() {
      $(this).css({
        'color': ''
      });
      return root.mouse.hot = false;
    });
    $('.arrow').click(function() {
      return root.SwipePane();
    });
    $('#grasshopper').click(function(e) {
      return e.stopPropagation();
    });
    $('#wideband').mousemove(function(e) {
      var p, x, y;
      p = $(this).position();
      x = root.mouse.position.x = e.clientX - p.left;
      y = root.mouse.position.y = e.clientY - p.top;
      root.mouse.within = 1;
      return root.mouse.moved = true;
    });
    $('#wideband').click(function(e) {
      var p, x, y;
      p = $(this).position();
      x = root.mouse.position.x = e.clientX - p.left;
      y = root.mouse.position.y = e.clientY - p.top;
      root.mouse.within = 1;
      return renderer.click();
    });
    return $('#wideband').mouseout(function() {
      root.mouse.position.x = -1;
      root.mouse.position.y = -1;
      return root.mouse.within = false;
    });
  };

  exportScreenshot = function() {
    var c, imgUrl;
    c = $('canvas').get(0);
    root.renderer.render();
    imgUrl = c.toDataURL("image/png");
    window.open(imgUrl, '_blank');
    return window.focus();
  };

  updateNumeralSizes = function() {
    $('#crossings').css('font-size', CurrentSizes.crossings);
    $('#superscript').css('font-size', CurrentSizes.numComponents);
    return $('#subscript').css('font-size', CurrentSizes.index);
  };

  getPagePosition = function(pageIndex) {
    var pageWidth;
    pageWidth = parseInt($('#canvaspage').css('width'));
    if (pageIndex === 1) {
      return 0;
    } else {
      return pageWidth;
    }
  };

  updateSwipeAnimation = function() {
    var h, w;
    w = parseInt($('#canvaspage').css('width'));
    h = parseInt($('#canvaspage').css('height'));
    $('#leftpage').css('left', -w + root.pan.x);
    $('#leftpage').css('width', w);
    $('#rightpage').css('left', 0 + root.pan.x);
    return $('#rightpage').css('width', w);
  };

  layout = function() {
    var bodyWidth, c, height, width;
    height = parseInt($('#wideband').css('height'));
    width = height * 768 / 1024;
    $('#wideband').css('width', width);
    bodyWidth = parseInt($('body').css('width'));
    $('#wideband').css('left', bodyWidth / 2 - width / 2);
    width = parseInt($('#canvaspage').css('width'));
    if (root.swipeTween != null) {
      root.swipeTween.stop();
    }
    height = parseInt($('#canvaspage').css('height'));
    c = $('canvas').get(0);
    c.clientWidth = width;
    c.width = c.clientWidth;
    c.clientHeight = height;
    c.height = c.clientHeight;
    this.renderer.width = width;
    this.renderer.height = height;
    root.pan.x = getPagePosition(root.pageIndex);
    return updateSwipeAnimation();
  };

}).call(this);
