.pragma library

var palettes = {
    wiki: {
        kind: "orange", body: "#33261F", header: "#D14924", sidebar: "#3D2B22",
        light4: "#F28A56", light3: "#E66B3D", dark4: "#A83B20", dark3: "#742A1D",
        text: "#FFF4EE", muted: "#DABDB0", accent: "#FFB088"
    },
    news: {
        kind: "purple", body: "#282036", header: "#7C4D9E", sidebar: "#312541",
        light4: "#B889D0", light3: "#9664B5", dark4: "#633D80", dark3: "#432B59",
        text: "#FAF2FF", muted: "#CBB9D5", accent: "#D8A8EF"
    },
    beatmap: {
        kind: "blue", body: "#1F2938", header: "#2867A5", sidebar: "#243247",
        light4: "#68A7DA", light3: "#4389C2", dark4: "#245581", dark3: "#193B5D",
        text: "#F1F8FF", muted: "#B5C8D8", accent: "#8CC8F2"
    }
}

function forRoute(route) {
    return palettes[route] || ({})
}
