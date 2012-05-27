var pan;
var tween;

function init()
{
    window.mouse = {}
    window.mouse.position = {x: -1, y: -1};
    window.mouse.within = false;
    window.mouse.hot = false;
    pan = {x: 0};
    window.AppInit();
    layout();
}

function layout()
{
    height = parseInt($("#wideband").css('height'));
    width = height*768/1024;
    $("#wideband").css("width", width);

    bodyWidth = parseInt($("body").css('width'));
    $("#wideband").css("left", bodyWidth / 2 - width / 2);

    width = parseInt($("#canvaspage").css('width'));
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

function inArrow(element)
{
    q = $("#" + element.id)
    q.css('color', '#cdf');
    //q.css('font-weight', '600');
    //q.css('cursor', 'pointer');
    window.mouse.hot = 1;
}

function outArrow(element)
{
    q = $("#" + element.id)
    q.css({'color' : ''});
    //q.css({'font-weight' : ''});
    //q.css({'cursor' : ''});
    window.mouse.hot = false;
}

function clickArrow(element)
{
    width = parseInt($("#canvaspage").css('width'));
    panTarget = element.id == "leftarrow" ? width : 0
    tween = new TWEEN.Tween(pan)
        .to({x: panTarget}, 1000)
        .easing(TWEEN.Easing.Bounce.Out)
        .onUpdate(updateTween);
    tween.start()
}

function updateTween()
{
    w = parseInt($("#canvaspage").css('width'));
    h = parseInt($("#canvaspage").css('height'));
    $("#leftpage").css("left", -w + pan.x);
    $("#leftpage").css("width", w - 40);
    $("#rightpage").css("left", 0 + pan.x);
    $("#rightpage").css("width", w - 40);
}

function mouseMove(event)
{
    var p = $('#wideband').position();
    var x = window.mouse.position.x = event.clientX - p.left;
    var y = window.mouse.position.y = event.clientY - p.top;
    window.mouse.within = 1;
}

function mouseClick(event)
{
    mouseMove(event);
    window.MouseClick();
}

function mouseLeave(event)
{
    window.mouse.position.x = -1;
    window.mouse.position.y = -1;
    window.mouse.within = false;
}
