import QtQuick
import Quickshell
import "modules/bar" as Bar
import "modules/bar/widgets" as Widgets
import "modules/lazerbar" as Lazer
Item {
    id: root
    width:1; height:1
    Bar.BarPopupHost { id: host; screenWidth: 1920; screenHeight:1080; effectiveBarHeight:48; floatingMargin:4 }
    Widgets.Volume { id: volWidget; visible:false }
    property var samples:[]
    Timer {
        id: sampler
        interval: 15; repeat:true
        onTriggered:{
            var p=host.popupItem; if(!p) return
            var sY=p.sidebarLayer.y + p.sidebarLayer.transform[0].y
            var cY=p.contentLayer.y + p.contentLayer.transform[0].y
            console.log("[R] p="+p.revealProgress.toFixed(3)+" sY="+sY.toFixed(1)+" cY="+cY.toFixed(1)+" sH="+p.sidebarLayer.height+" cH="+p.contentLayer.height+" popupH="+p.height+" dist="+host.revealDistance+" targetH="+host.targetHeight+" displayH="+host.displayHeight)
        }
    }
    Timer {
        id: seq
        interval: 80
        onTriggered:{
            var intent = volWidget.buildHoverIntent()
            // patch anchor and screen for determinism
            intent.anchorX = 400
            intent.screenWidth=1920; intent.screenHeight=1080; intent.effectiveBarHeight=48; intent.floatingMargin=4; intent.barPosition="top"
            console.log("INTENT", JSON.stringify(intent))
            host.showIntent(intent)
            sampler.start()
        }
    }
    Timer { id: closeT; interval:1500; onTriggered:{ host.widgetHovered=false; host.popupHovered=false; host.requestClose() } }
    Timer { id: finish; interval:2500; onTriggered:{ sampler.stop(); Qt.quit() } }
    Component.onCompleted:{ Qt.callLater(function(){ seq.start(); closeT.start(); finish.start() }) }
}
