.pragma library

// Capsule spacing language borrowed from Apple WWDC23 Dynamic Island fit guidance
// (concentric margins, avoid corner tension) and Material chip spacing norms.

var compactSidePadding = 12;
var compactVerticalPadding = 6;
var regularSidePadding = 16;
var regularVerticalPadding = 8;

var compactInnerHorizontal = compactSidePadding * 2;
var compactInnerVertical = compactVerticalPadding * 2;
var regularInnerHorizontal = regularSidePadding * 2;
var regularInnerVertical = regularVerticalPadding * 2;

var groupGap = 8;
var inlineGap = 6;
var iconGap = 4;

function concentricInnerRadius(outerRadius, inset) {
    return Math.max(0, outerRadius - inset);
}
