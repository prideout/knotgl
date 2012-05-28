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

$(document).ready(function(e) { window.AppInit(); });
