var tween;

// Vertex Attribute Semantics
VERTEXID = 0;
POSITION = 0;
NORMAL   = 1;
TEXCOORD = 2;

// Global Utilities
function glerr(msg) { $.gritter.add({ title: 'WebGL Error', text: msg }); }
function toast(msg) { $.gritter.add({ title: 'Notice', text: msg }); }

$(document).keydown(function(e){
    if (e.keyCode == 37) window.OnKeyDown('left');
    if (e.keyCode == 39) window.OnKeyDown('right');
});

function layout()
{
    height = parseInt($("#wideband").css('height'));
    width = height*768/1024;
    $("#wideband").css("width", width);

    bodyWidth = parseInt($("body").css('width'));
    $("#wideband").css("left", bodyWidth / 2 - width / 2);

    width = window.pan.width = parseInt($("#canvaspage").css('width'));
    height = parseInt($("#canvaspage").css('height'));
    c = $("canvas").get(0);
    c.clientWidth = width;
    c.width = c.clientWidth;
    c.clientHeight = height;
    c.height = c.clientHeight;
    this.renderer.width = width;
    this.renderer.height = height;

    updateTween();
}

function updateTween()
{
    w = parseInt($("#canvaspage").css('width'));
    h = parseInt($("#canvaspage").css('height'));
    $("#leftpage").css("left", -w + window.pan.x);
    $("#leftpage").css("width", w - 40);
    $("#rightpage").css("left", 0 + window.pan.x);
    $("#rightpage").css("width", w - 40);
}

$(document).ready(function(e){
    window.mouse = {}
    window.mouse.position = {x: -1, y: -1};
    window.mouse.within = false;
    window.mouse.hot = false;
    window.pan = {x: 0};
    window.AppInit();
    layout();

    $(".arrow").mouseover(function(){
      $(this).css('color', '#cdf');
      window.mouse.hot = 1;
    });

    $(".arrow").mouseout(function(){
      $(this).css({'color' : ''});
      window.mouse.hot = false;
    });

    $(".arrow").click(function(){
      panTarget = $(this).attr('id') == "leftarrow" ? window.pan.width : 0
      swipeDuration = 1000
      tween = new TWEEN.Tween(window.pan)
          .to({x: panTarget/2}, swipeDuration)
          .easing(TWEEN.Easing.Bounce.Out)
          .onUpdate(updateTween);
      tween.start()
    });

    $("#wideband").mousemove(function(e){
        var p = $(this).position();
        var x = window.mouse.position.x = e.clientX - p.left;
        var y = window.mouse.position.y = e.clientY - p.top;
        window.mouse.within = 1;
    });

    $("#wideband").click(function(e){
        var p = $(this).position();
        var x = window.mouse.position.x = e.clientX - p.left;
        var y = window.mouse.position.y = e.clientY - p.top;
        window.mouse.within = 1;
        window.MouseClick();
    });

    $("#wideband").mouseout(function(e){
        window.mouse.position.x = -1;
        window.mouse.position.y = -1;
        window.mouse.within = false;
    });
});
