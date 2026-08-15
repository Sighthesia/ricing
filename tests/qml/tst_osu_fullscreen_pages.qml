import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Verify that each sparse template keeps its distinct osu page structure and palette.
Item {
    width: 1200; height: 720
    Lazer.WikiLikePage { id: wiki; width: 1200; height: 720 }
    Lazer.NewsLikePage { id: news; width: 1200; height: 720; visible: false }
    Lazer.BeatmapLikePage { id: beatmap; width: 1200; height: 720; visible: false }
    TestCase {
        name: "OsuFullscreenPages"
        function test_structuralIdentity() {
            compare(wiki.pageKind, "wiki"); compare(wiki.paletteKind, "orange")
            verify(wiki.sidebarItemCount >= 3); verify(wiki.sampleItemCount >= 2)
            compare(news.pageKind, "news"); compare(news.paletteKind, "purple")
            verify(news.sidebarItemCount >= 3); verify(news.sampleItemCount >= 3)
            compare(beatmap.pageKind, "beatmap"); compare(beatmap.paletteKind, "blue")
            verify(beatmap.sidebarItemCount >= 3); verify(beatmap.sampleItemCount >= 4)
        }
        function test_fixedPalettesDoNotShareIdentity() {
            verify(wiki.palette.body !== news.palette.body)
            verify(news.palette.body !== beatmap.palette.body)
            verify(beatmap.palette.body !== wiki.palette.body)
        }
    }
}
