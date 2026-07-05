import skse;
import skyui.defines.Inventory;
import Shared.GlobalFunc;
import mx.transitions.Tween;
import mx.transitions.easing.*;

class LoreBox extends MovieClip {

    public static var instance;

    /* stage elements */
    public var Background_mc:MovieClip;
    public var TooltipText_tf:TextField;
    public var Placeholder_tf:TextField;
    public var ImagesContainer_mc:MovieClip;

    /* refs */
    public var inventoryLists:MovieClip;
    public var itemList:MovieClip;

    /* config */
    private var prefix:String = 'LoreBox_';
    public var MarginRight:Number = 40;
    public var BackgroundPadding:Number = 40;
    public var delay:Number = 0;

    /* state */
    private var timer:Number;
    private var imageMarker:String = '___image___';
    private var imageYOffset:Number = 0;

    function LoreBox() {
        LoreBox.instance = this;
        _alpha = 0;
        Placeholder_tf._visible = false;
    }

    function onLoad() {
        GlobalFunc.MaintainTextFormat();
        var Menu_mc = _parent._parent.Menu_mc
                ? _parent._parent.Menu_mc
                : _parent._parent.Menu; // Crafting menu
        delay = parseInt(_parent._name.split('_')[1]);
        if ( typeof Menu_mc.bCanCraft === 'boolean' ) {
            inventoryLists = Menu_mc.InventoryLists;
            itemList = Menu_mc.ItemList;
        } else {
            inventoryLists = Menu_mc.inventoryLists;
            itemList = inventoryLists.itemList;
        }

        startListening();
        TooltipText_tf.multiline = true;
        TooltipText_tf.wordWrap = true;
        TooltipText_tf.autoSize = 'left';
        if ( itemList.selectedIndex !== -1 ) {
            redraw();
        }
    }

    public function redraw() {
        onItemHighlightChange( { index: itemList.selectedIndex } );
    }

    function startListening() {
        inventoryLists.addEventListener("categoryChange", this, "onCategoryChange");
        inventoryLists.addEventListener("itemHighlightChange", this, "onItemHighlightChange");
    }

    private function onItemHighlightChange(event: Object): Void {
        this.onEnterFrame = null;
        if ( event.index !== -1 ) {
            var keywords:Object = itemList.selectedEntry.keywords
                ? itemList.selectedEntry.keywords // Item keywords
                : itemList.selectedEntry.effectKeywords; // Magic keywords
            var matchingKeywords:Array = findMatchingKeywords(keywords),
                tooltipText:String = "";
            if ( matchingKeywords.length ) {
                for ( var i = 0; i < matchingKeywords.length; i++ ) {
                    Placeholder_tf.text = '$' + matchingKeywords[ i ];
                    if (Placeholder_tf.text !== '$' + matchingKeywords[ i ]) { // we actually translated the keyword
                        tooltipText += Placeholder_tf.text + "<br>";
                    }
                }
            }

            if ( tooltipText !== '' ) {
                var targetMC = itemList.getClipByIndex(itemList.selectedEntry.clipIndex),
                    images:Array = new Array(),
                    img:Object,
                    nextImageIndex = 0;
                while ( (img = extractFirstImageTag(tooltipText, nextImageIndex)) !== undefined ) {
                    images.push(img);
                    /**
                     * <br> around imageMarker to ensure it's on its own line
                     * <img> is wrapped with <p> since it breaks the line for whatever comes after the image
                     */
                    var imagePlaceholder = (img.index !== 0 ? '<br>' : '') + '<font size="0">' + imageMarker + '</font><br>' + '<p><img src="" height="' + img.height + '"></p>';
                    tooltipText = tooltipText.substr(0, img.index) + imagePlaceholder + tooltipText.substr(img.index + img.length);
                    nextImageIndex = img.index + imagePlaceholder.length;
                }

                // apply the html result, then reset tooltipText
                TooltipText_tf.SetText(tooltipText, true);
                tooltipText = TooltipText_tf.text;
                Background_mc._height = TooltipText_tf._height + BackgroundPadding;
                Background_mc._y = Background_mc._height / 2;

                clearMovieClip(ImagesContainer_mc);
                var charIndex:Number = 0,
                    sizeInfo = {};
                for ( var i = 0; i < images.length; i++ ) {
                    /* use plain text to find imageMarker character indexes, getExactCharBoundaries ignores HTML tags it seems */
                    charIndex = tooltipText.indexOf(imageMarker, charIndex);
                    var position = TooltipText_tf.getExactCharBoundaries(charIndex),
                        mc = ImagesContainer_mc.createEmptyMovieClip('image_' + i, ImagesContainer_mc.getNextHighestDepth()),
                        loader:MovieClipLoader = new MovieClipLoader(),
                        listener:Object = {};
                    /* cache image size data */
                    sizeInfo[mc] = [images[i].width, images[i].height];

                    listener.onLoadInit = function(target_mc:MovieClip):Void {
                        target_mc._width = sizeInfo[target_mc][0];
                        target_mc._height = sizeInfo[target_mc][1];
                    };
                    loader.addListener(listener);
                    loader.loadClip(images[i].url, mc);
                    mc._y = position.y + imageYOffset;
                    if ( images[i].width < TooltipText_tf._width ) {
                        mc._x = (TooltipText_tf._width / 2) - (images[i].width / 2);
                    }
                    charIndex++;
                }

                startFadeIn();
                if ( targetMC.hitTest(_root._xmouse, _root._ymouse) ) { /* mouse is here */
                    this.onEnterFrame = function() {
                        if ( targetMC.hitTest( _root._xmouse, _root._ymouse ) ) {
                            _x = _root._xmouse + MarginRight;
                            var y = _root._ymouse;
                            // lorebox is sticking out from bottom
                            if ( _root._ymouse + _height > Stage.visibleRect.height ) {
                                y -= _height;
                            }
                            _y = y;
                        } else {
                            /* going outside the bounds of Inventory UI */
                            fadeOut();
                            this.onEnterFrame = null;
                        }
                    }
                } else {
                    /* navigated by keyboard/controller */
                    var points = { x : targetMC._x, y : targetMC._y };
                    targetMC._parent.localToGlobal( points );
                    _x = points.x + ( targetMC._width / 2 );
                    var y = points.y + ( targetMC._height / 2 );
                    if ( y + _height > Stage.visibleRect.height ) {
                        y -= _height;
                    }
                    _y = y;
                }
            } else {
                fadeOut();
            }
        }
    }

    private function onCategoryChange(event: Object): Void {
        fadeOut();
        this.onEnterFrame = null;
	}

    function findMatchingKeywords(keywordsList:Object) : Array {
        var output:Array = [];
        for ( var keyword in keywordsList ) {
            if ( keyword.substr(0, prefix.length) === prefix ) {
                output.push(keyword);
            }
        }

        return output;
    }

    function startFadeIn() {
        clearTimeout(timer);
        timer = setTimeout(fadeIn, delay);
    }

    function fadeIn() {
        this = LoreBox.instance;
        fadeMC(this, 100, 0.5);
    }

    function fadeOut() {
        clearTimeout(timer);
        fadeMC(this, 0, 0.5);
    }

    function fadeMC(mc:MovieClip, targetAlpha:Number, duration:Number):Void {
        if (mc._fadeTween instanceof Tween) {
            mc._fadeTween.stop();
        }
        if (targetAlpha > mc._alpha) {
            mc._visible = true;
        }
        mc._fadeTween = new Tween(mc, "_alpha", Regular.easeOut, mc._alpha, targetAlpha, duration, true);
        mc._fadeTween.onMotionFinished = function() {
            if (targetAlpha == 0) {
                mc._visible = false;
            }
        };
    }

    function extractFirstImageTag(html:String, fromIndex:Number):Object {
        var lowerHtml:String = html.toLowerCase();
        var imgIndex:Number = lowerHtml.indexOf("<img", fromIndex);

        if (imgIndex == -1) {
            return undefined;
        }

        var tagEnd:Number = lowerHtml.indexOf(">", imgIndex);
        if (tagEnd == -1) {
            return undefined; // malformed tag
        }

        var tag:String = html.substring(imgIndex, tagEnd + 1);

        // Helper to extract attribute values
        function getAttr(tag:String, attr:String):String {
            var attrIndex:Number = tag.toLowerCase().indexOf(attr + "=");
            if (attrIndex == -1) return undefined;

            var start:Number = attrIndex + attr.length + 1;
            var quote:String = tag.charAt(start);
            var end:Number;

            if (quote == '"' || quote == "'") {
                start += 1;
                end = tag.indexOf(quote, start);
            } else {
                // Unquoted value
                end = tag.indexOf(" ", start);
                if (end == -1) end = tag.length;
            }

            if (end == -1) return undefined;
            return tag.substring(start, end);
        }

        var src:String = getAttr(tag, "src");
        if (src == undefined || src.substr(-4).toLowerCase() !== '.dds') return undefined;

        var widthStr:String = getAttr(tag, "width");
        var heightStr:String = getAttr(tag, "height");

        return {
            url: src,
            width: widthStr != undefined ? Number(widthStr) : undefined,
            height: heightStr != undefined ? Number(heightStr) : undefined,
            index: imgIndex,
            length: tag.length
        };
    }

    function clearMovieClip(parentMC:MovieClip) : Void {
        for ( var mc in parentMC ) {
            if ( typeof parentMC[mc] === 'movieclip' ) {
                parentMC[mc].removeMovieClip();
            }
        }
    }

    public static function LogObject( obj ) {
        var s = '';
        for ( var i in obj ) {
            s += i + ': ' + obj[i] + ';\n';
        }
        skse.Log(s);
    }
}