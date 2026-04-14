(function () {
  'use strict';

  const BRIDGE_URL = 'http://127.0.0.1:18765/push';
  const LYRIC_API_PREFIX = 'https://music.163.com/api/song/lyric?id=';
  const lyricCache = new Map();

  function normalizePlaybackState(value) {
    const normalized = value == null ? '' : String(value).trim().toLowerCase();
    switch (normalized) {
      case 'playing':
      case 'play':
        return 'playing';
      case 'paused':
      case 'pause':
        return 'paused';
      case 'none':
      case 'stopped':
      case 'stop':
      default:
        return 'stopped';
    }
  }

  function normalizePayload(rawPayload) {
    const payload = rawPayload && typeof rawPayload === 'object' ? rawPayload : {};
    return {
      songId: payload.songId == null ? '' : String(payload.songId).trim(),
      title: payload.title == null ? '' : String(payload.title).trim(),
      artist: payload.artist == null ? '' : String(payload.artist).trim(),
      playbackState: normalizePlaybackState(payload.playbackState),
      durationMs: Number.isFinite(Number(payload.durationMs)) ? Math.max(0, Math.round(Number(payload.durationMs))) : 0,
      positionMs: Number.isFinite(Number(payload.positionMs)) ? Math.max(0, Math.round(Number(payload.positionMs))) : 0,
      progress: Number.isFinite(Number(payload.progress)) ? Math.max(0, Math.min(1, Number(payload.progress))) : 0,
      rawLyric: payload.rawLyric == null ? '' : String(payload.rawLyric).trim(),
      translatedLyric: payload.translatedLyric == null ? '' : String(payload.translatedLyric).trim(),
    };
  }

  function fetchLyrics(songId) {
    if (!songId)
      return Promise.resolve({ rawLyric: '', translatedLyric: '' });

    if (lyricCache.has(songId))
      return Promise.resolve(lyricCache.get(songId));

    return fetch(LYRIC_API_PREFIX + encodeURIComponent(songId) + '&lv=1&kv=1&tv=-1', {
      credentials: 'omit',
      mode: 'cors'
    })
      .then((response) => response.ok ? response.json() : {})
      .then((data) => {
        const lyrics = {
          rawLyric: data && data.lrc && typeof data.lrc.lyric === 'string'
            ? data.lrc.lyric.trim()
            : '',
          translatedLyric: data && data.tlyric && typeof data.tlyric.lyric === 'string'
            ? data.tlyric.lyric.trim()
            : '',
        };
        lyricCache.set(songId, lyrics);
        return lyrics;
      })
      .catch(() => ({ rawLyric: '', translatedLyric: '' }));
  }

  function pushToBridge(payload) {
    return fetch(BRIDGE_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload),
      mode: 'cors'
    }).then(() => ({ ok: true })).catch((error) => ({ ok: false, error: String(error) }));
  }

  browser.runtime.onMessage.addListener((message) => {
    if (!message || message.type !== 'dymicshell-netease-lyrics-push')
      return Promise.resolve({ ok: false, ignored: true });

    const payload = normalizePayload(message.payload);
    if (payload.songId === '' || payload.rawLyric !== '' || payload.translatedLyric !== '')
      return pushToBridge(payload);

    return fetchLyrics(payload.songId).then((lyrics) => {
      return pushToBridge({
        ...payload,
        rawLyric: lyrics.rawLyric || payload.rawLyric,
        translatedLyric: lyrics.translatedLyric || payload.translatedLyric,
      });
    });
  });
})();
