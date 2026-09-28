import QtQuick
import Quickshell
import "modules/bar" as Bar
import "modules/lazerbar" as Lazer
Item {
    id: root
    width:1; height:1
    Bar.BarPopupHost {
        id: host
        screenWidth: 1000; screenHeight: 900
        effectiveBarHeight: 48; floatingMargin: 4
    }
    property var samples: []
    Timer {
        id: sampler
        interval: 15
        repeat: true
        onTriggered: {
            var p = host.popupItem
            if (!p) return
            var sY = p.sidebarLayer.y + p.sidebarLayer.transform[0].y
            var cY = p.contentLayer.y + p.contentLayer.transform[0].y
            var rec = {
                t: Date.now(),
                p: Number(p.revealProgress.toFixed(3)),
                cp: Number(p.contentRevealProgress.toFixed(3)),
                sY: Math.round(sY*10)/10,
                cY: Math.round(cY*10)/10,
                sH: Math.round(p.sidebarLayer.height),
                cH: Math.round(p.contentLayer.height),
                popupH: Math.round(p.height),
                containerH: Math.round(host.popupContainerItem.height),
                viewportH: Math.round(host.popupViewportItem.height),
                displayH: Math.round(host.displayHeight),
                targetH: Math.round(host.targetHeight),
                dist: Math.round(host.revealDistance),
                sVis: Math.round(Math.max(0, Math.min(p.sidebarLayer.height, p.height - sY - (p.sidebarLayer.y)))),
                cVis: Math.round(Math.max(0, Math.min(p.contentLayer.height, p.height - cY - (p.contentLayer.y - p.sidebarLayer.height -1)))),
                // simpler visible within popup: popup height - y
                sVis2: Math.round(Math.max(0, p.height - sY)),
                cVis2: Math.round(Math.max(0, p.height - cY - (p.contentLayer.y)))
            }
            samples.push(rec)
            console.log("[S] p="+rec.p+" cp="+rec.cp+" sY="+rec.sY+" cY="+rec.cY+" sH="+rec.sH+" cH="+rec.cH+" popupH="+rec.popupH+" containerH="+rec.containerH+" viewportH="+rec.viewportH+" dist="+rec.dist)
        }
    }
    Timer {
        id: seq
        interval: 80
        onTriggered: {
            console.log("=== OPEN top volume ===")
            host.showIntent({
                widgetId:"volume", instanceKey:"volume:0", title:"Volume",
                iconSource:Qt.resolvedUrl("modules/bar/icons/volume.svg"), summary:"45%",
                actionKind:"volume", anchorX:400, screenWidth:1000, screenHeight:900,
                effectiveBarHeight:48, floatingMargin:4, barPosition:"top",
                payload:{ volume:0.5 }
            })
            sampler.start()
        }
    }
    Timer {
        id: closeTimer
        interval: 1200
        onTriggered: {
            console.log("=== TRIGGER CLOSE ===")
            host.widgetHovered=false; host.popupHovered=false; host.requestClose()
        }
    }
    Timer {
        id: finish
        interval: 2500
        onTriggered: {
            sampler.stop()
            console.log("=== ANALYZE "+samples.length+" ===")
            var fails=0
            for(var i=1;i<samples.length;i++){
                var prev=samples[i-1], cur=samples[i]
                // check jump >10 in one tick for sY/cY while p increases
                if(cur.p > prev.p + 0.005){
                    if(Math.abs(cur.sY - prev.sY) > 12) { console.log("JUMP sY at i="+i+" "+prev.sY+"->"+cur.sY+" p "+prev.p+"->"+cur.p); fails++ }
                    if(Math.abs(cur.cY - prev.cY) > 12) { console.log("JUMP cY at i="+i+" "+prev.cY+"->"+cur.cY); fails++ }
                } else if(cur.p < prev.p -0.005){
                    if(Math.abs(cur.sY - prev.sY) > 12) { console.log("JUMP sY close at i="+i+" "+prev.sY+"->"+cur.sY); fails++ }
                    if(Math.abs(cur.cY - prev.cY) > 12) { console.log("JUMP cY close at i="+i); fails++ }
                }
                // check half truncation: at p 0.45-0.55, visible should be ~ half, not 0 or full
                // Instead check if cVis suddenly drops to 0 at half
            }
            // find half open and half close
            var halfOpen=null, halfClose=null
            for(var j=0;j<samples.length;j++){
                if(!halfOpen && samples[j].p>0.45 && samples[j].p<0.55 && samples[j].p>0) halfOpen=samples[j]
            }
            for(var k=samples.length-1;k>=0;k--){
                if(!halfClose && samples[k].p>0.45 && samples[k].p<0.55) halfClose=samples[k]
            }
            if(halfOpen) console.log("HALF_OPEN p="+halfOpen.p+" sY="+halfOpen.sY+" cY="+halfOpen.cY+" sH="+halfOpen.sH+" cH="+halfOpen.cH+" popupH="+halfOpen.popupH+" sVis2="+halfOpen.sVis2+" cVis2="+halfOpen.cVis2)
            if(halfClose) console.log("HALF_CLOSE p="+halfClose.p+" sY="+halfClose.sY+" cY="+halfClose.cY)
            // also check final endpoint hide
            var last=samples[samples.length-1]
            console.log("LAST p="+last.p+" sY="+last.sY+" cY="+last.cY+" dist="+last.dist)
            if(fails>0) console.log("RED: jump detected")
            else console.log("GREEN: no jump")
            Qt.quit()
        }
    }
    Component.onCompleted: { Qt.callLater(function(){ seq.start(); closeTimer.start(); finish.start() }) }
}
