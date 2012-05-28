// Vertex Attribute Semantics
VERTEXID = 0;
POSITION = 0;
NORMAL   = 1;
TEXCOORD = 2;

COLORS = {
    black: [0,0,0],
    darkgray:  [.1,.1,.1],
};

// Global Utilities
function glerr(msg) { $.gritter.add({ title: 'WebGL Error', text: msg }); }
function toast(msg) { $.gritter.add({ title: 'Notice', text: msg }); }

function swipePane(direction)
{
    panTarget = direction == -1 ? window.pan.width : 0;
    swipeDuration = 1000;
    tween = new TWEEN.Tween(window.pan)
        .to({x: panTarget}, swipeDuration)
        .easing(TWEEN.Easing.Bounce.Out)
        .onUpdate(updateTween);
    tween.start();
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
    window.AppInit();

    $(".arrow").mouseover(function(){
      $(this).css('color', '#385fa2');
      window.mouse.hot = 1;
    });

    $(".arrow").mouseout(function(){
      $(this).css({'color' : ''});
      window.mouse.hot = false;
    });

    $(".arrow").click(function(){
      var swipeDirection = $(this).attr('id') == "leftarrow" ? -1 : +1;
      swipePane(swipeDirection)
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
