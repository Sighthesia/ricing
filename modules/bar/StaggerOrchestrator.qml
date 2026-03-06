import QtQuick
import qs.services

// Shared helper to orchestrate stagger enter/exit for a group of StaggerItem targets.
Item {
    id: root

    property var _entries: []

    function clear() {
        _entries = [];
    }

    function registerItem(item, order, level) {
        if (!item) return;
        _entries.push({
            item: item,
            order: Number.isFinite(order) ? order : 0,
            level: level === 2 ? 2 : 1
        });
    }

    function _sortedEntries() {
        let copy = _entries.slice();
        copy.sort((a, b) => a.order - b.order);
        return copy;
    }

    function _delayFor(entry) {
        let anim = SettingsService.data.animation;
        if (entry.level === 2) {
            return anim.staggerLevel2BaseDelay + anim.staggerLevel2Step * entry.order;
        }
        return anim.staggerLevel1BaseDelay + anim.staggerLevel1Step * entry.order;
    }

    function runEnter() {
        let entries = _sortedEntries();
        for (let i = 0; i < entries.length; i++) {
            let target = entries[i].item;
            if (!target || typeof target.runEnter !== "function") continue;
            target.delay = _delayFor(entries[i]);
            target.runEnter();
        }
    }

    function runExit() {
        let entries = _sortedEntries();
        for (let i = 0; i < entries.length; i++) {
            let target = entries[i].item;
            if (!target || typeof target.runExit !== "function") continue;
            target.exitDelay = 0;
            target.runExit();
        }
    }
}
