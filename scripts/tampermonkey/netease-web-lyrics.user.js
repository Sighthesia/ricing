// ==UserScript==
// @name         Afloat NetEase Lyrics Bridge
// @namespace    https://sighthesia/afloat
// @version      0.2.2
// @description  Capture NetEase web lyrics state and forward it to afloat's localhost bridge.
// @match        https://music.163.com/*
// @run-at       document-start
// @grant        GM_xmlhttpRequest
// @grant        GM_addElement
// @grant        unsafeWindow
// @connect      127.0.0.1
// @connect      music.163.com
// ==/UserScript==

(function () {
  'use strict';

  const MESSAGE_TYPE = 'afloat-netease-lyrics-state';
  const EVENT_TYPE = 'afloat-netease-lyrics-state-event';
  const BRIDGE_URL = 'http://127.0.0.1:18765/push';
  const LYRIC_API_PREFIX = 'https://music.163.com/api/song/lyric?id=';
  const SEARCH_API_PREFIX = 'https://music.163.com/api/search/get/web?csrf_token=&type=1&offset=0&total=true&limit=10&s=';
  const DEBUG_PREFIX = '[afloat:NeteaseLyricsUserscript]';
  const DEBUG_ENABLED = window.localStorage && window.localStorage.getItem('afloatNeteaseLyricsDebug') === '1';

  const lyricCache = new Map();
  const songIdLookupCache = new Map();
  let lastForwardedSignature = '';
  let latestLookupKey = '';
  let lastDebugSignature = '';
  let bridgeFailureCount = 0;

  function debugLog(reason, details) {
    if (!DEBUG_ENABLED)
      return;

    const signature = reason + '|' + JSON.stringify(details || {});
    if (signature === lastDebugSignature)
      return;

    lastDebugSignature = signature;
    console.info(DEBUG_PREFIX, reason, details || {});
  }

  function normalizeText(value) {
    return value == null ? '' : String(value).trim();
  }

  function clampInt(value) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed))
      return 0;
    return Math.max(0, Math.round(parsed));
  }

  function normalizePayload(rawPayload) {
    const payload = rawPayload && typeof rawPayload === 'object' ? rawPayload : {};
    const durationMs = clampInt(payload.durationMs);
    const positionMs = clampInt(payload.positionMs);
    const progress = durationMs > 0 ? Math.max(0, Math.min(1, positionMs / durationMs)) : 0;

    return {
      songId: normalizeText(payload.songId),
      title: normalizeText(payload.title),
      artist: normalizeText(payload.artist),
      playbackState: normalizeText(payload.playbackState) || 'stopped',
      durationMs,
      positionMs,
      progress,
      rawLyric: normalizeText(payload.rawLyric),
      translatedLyric: normalizeText(payload.translatedLyric),
    };
  }

  function payloadSignature(payload) {
    return [
      payload.songId,
      payload.title,
      payload.artist,
      payload.playbackState,
      payload.positionMs,
      payload.durationMs,
      payload.rawLyric,
      payload.translatedLyric,
    ].join('|');
  }

  function postToBridge(payload) {
    const normalized = normalizePayload(payload);
    const signature = payloadSignature(normalized);

    if (signature === lastForwardedSignature)
      return;

    lastForwardedSignature = signature;
    debugLog('bridge:post', {
      songId: normalized.songId,
      title: normalized.title,
      artist: normalized.artist,
      playbackState: normalized.playbackState,
      positionMs: normalized.positionMs,
      durationMs: normalized.durationMs,
      hasRawLyric: normalized.rawLyric !== '',
      hasTranslatedLyric: normalized.translatedLyric !== '',
    });

    GM_xmlhttpRequest({
      method: 'POST',
      url: BRIDGE_URL,
      headers: {
        'Content-Type': 'application/json',
      },
      data: JSON.stringify(normalized),
      onload: (response) => {
        bridgeFailureCount = 0;
        if (!response || response.status < 200 || response.status >= 300) {
          console.warn(DEBUG_PREFIX, 'bridge:unexpectedStatus', {
            status: response ? response.status : 0,
            statusText: response ? response.statusText : '',
          });
        }
      },
      onerror: (error) => {
        bridgeFailureCount += 1;
        console.warn(DEBUG_PREFIX, 'bridge:error', {
          count: bridgeFailureCount,
          error: error && error.error ? String(error.error) : 'network-error',
        });
      },
      ontimeout: () => {
        bridgeFailureCount += 1;
        console.warn(DEBUG_PREFIX, 'bridge:timeout', {
          count: bridgeFailureCount,
        });
      },
    });
  }

  function requestJson(url, options = {}) {
    const method = options.method || 'GET';
    const data = options.data == null ? null : options.data;
    const headers = options.headers || {};

    return new Promise((resolve, reject) => {
      GM_xmlhttpRequest({
        method,
        url,
        data,
        headers,
        onload: (response) => {
          const text = response && typeof response.responseText === 'string' ? response.responseText : '';
          try {
            resolve(text ? JSON.parse(text) : {});
          } catch (error) {
            reject(error);
          }
        },
        onerror: () => reject(new Error('network-error')),
        ontimeout: () => reject(new Error('timeout')),
      });
    });
  }

  function normalizeLookupText(value) {
    return value == null
      ? ''
      : String(value)
        .trim()
        .toLowerCase()
        .replace(/\s+/g, ' ');
  }

  function lookupKeyForPayload(payload) {
    const title = normalizeLookupText(payload && payload.title);
    if (!title)
      return '';

    const artist = normalizeLookupText(payload && payload.artist);
    const durationBucket = payload && payload.durationMs > 0
      ? String(Math.round(Number(payload.durationMs) / 1000))
      : '';
    return [title, artist, durationBucket].join('|');
  }

  function splitArtistNames(value) {
    const normalized = normalizeLookupText(value);
    if (!normalized)
      return [];

    return normalized.split(/\s*(?:,|\/|&|、)\s*/).filter(Boolean);
  }

  function songArtistNames(song) {
    if (!song || typeof song !== 'object')
      return [];

    if (Array.isArray(song.artists))
      return song.artists.map((artist) => normalizeLookupText(artist && artist.name)).filter(Boolean);

    if (Array.isArray(song.ar))
      return song.ar.map((artist) => normalizeLookupText(artist && artist.name)).filter(Boolean);

    return splitArtistNames(song.artist || '');
  }

  function scoreSongCandidate(song, payload) {
    const payloadTitle = normalizeLookupText(payload && payload.title);
    const payloadArtists = splitArtistNames(payload && payload.artist);
    const songTitle = normalizeLookupText(song && (song.name || song.title));
    if (!payloadTitle || !songTitle)
      return -1;

    let score = 0;
    if (songTitle === payloadTitle)
      score += 1000;
    else if (songTitle.includes(payloadTitle) || payloadTitle.includes(songTitle))
      score += 500;
    else
      return -1;

    const candidateArtists = songArtistNames(song);
    if (payloadArtists.length > 0) {
      const exactArtistMatch = payloadArtists.every((artist) => candidateArtists.includes(artist));
      const partialArtistMatch = payloadArtists.some(
        (artist) => candidateArtists.some((candidate) => candidate.includes(artist) || artist.includes(candidate))
      );

      if (exactArtistMatch)
        score += 500;
      else if (partialArtistMatch)
        score += 200;
      else
        return -1;
    }

    const candidateDuration = Number(song && (song.duration || song.dt || 0));
    const expectedDuration = Number(payload && payload.durationMs);
    if (Number.isFinite(candidateDuration) && candidateDuration > 0 && Number.isFinite(expectedDuration) && expectedDuration > 0) {
      const durationDifference = Math.abs(candidateDuration - expectedDuration);
      score += Math.max(0, 300 - Math.round(durationDifference / 1000));
    }

    return score;
  }

  function bestSongIdFromSearch(data, payload) {
    const songs = data && data.result && Array.isArray(data.result.songs)
      ? data.result.songs
      : (data && Array.isArray(data.songs) ? data.songs : []);
    let bestSongId = '';
    let bestScore = -1;

    for (const song of songs) {
      const candidateScore = scoreSongCandidate(song, payload);
      if (candidateScore <= bestScore)
        continue;

      const candidateSongId = song && song.id != null ? String(song.id).trim() : '';
      if (!candidateSongId)
        continue;

      bestSongId = candidateSongId;
      bestScore = candidateScore;
    }

    return bestSongId;
  }

  function searchSongIdByMetadata(payload) {
    const lookupKey = lookupKeyForPayload(payload);
    if (!lookupKey)
      return Promise.resolve('');

    if (songIdLookupCache.has(lookupKey))
      return songIdLookupCache.get(lookupKey);

    const query = [payload.title || '', payload.artist || ''].filter(Boolean).join(' ').trim();
    if (!query)
      return Promise.resolve('');

    const searchPromise = requestJson(SEARCH_API_PREFIX + encodeURIComponent(query))
      .then((data) => bestSongIdFromSearch(data, payload))
      .catch(() => '')
      .then((songId) => {
        const resolvedPromise = Promise.resolve(songId);
        songIdLookupCache.set(lookupKey, resolvedPromise);
        return songId;
      });

    songIdLookupCache.set(lookupKey, searchPromise);
    return searchPromise;
  }

  function fetchLyrics(songId) {
    if (!songId)
      return Promise.resolve({ rawLyric: '', translatedLyric: '' });

    if (lyricCache.has(songId))
      return Promise.resolve(lyricCache.get(songId));

    const lyricPromise = requestJson(LYRIC_API_PREFIX + encodeURIComponent(songId) + '&lv=1&kv=1&tv=-1')
      .then((data) => ({
        rawLyric: data && data.lrc && typeof data.lrc.lyric === 'string' ? data.lrc.lyric.trim() : '',
        translatedLyric: data && data.tlyric && typeof data.tlyric.lyric === 'string' ? data.tlyric.lyric.trim() : '',
      }))
      .catch(() => ({ rawLyric: '', translatedLyric: '' }));

    lyricCache.set(songId, lyricPromise);
    return lyricPromise;
  }

  function enrichAndPush(payload, songId) {
    const normalized = normalizePayload(payload);
    const resolvedPayload = songId ? { ...normalized, songId } : normalized;

    postToBridge(resolvedPayload);
    if (!resolvedPayload.songId)
      return;

    fetchLyrics(resolvedPayload.songId).then((lyrics) => {
      postToBridge({
        ...resolvedPayload,
        rawLyric: lyrics.rawLyric || resolvedPayload.rawLyric,
        translatedLyric: lyrics.translatedLyric || resolvedPayload.translatedLyric,
      });
    });
  }

  function handleStateMessage(rawPayload) {
    const normalized = normalizePayload(rawPayload);
    postToBridge(normalized);

    if (normalized.songId) {
      enrichAndPush(normalized, normalized.songId);
      return;
    }

    const lookupKey = lookupKeyForPayload(normalized);
    if (!lookupKey)
      return;

    latestLookupKey = lookupKey;
    searchSongIdByMetadata(normalized).then((songId) => {
      if (!songId || latestLookupKey !== lookupKey)
        return;

      enrichAndPush(normalized, songId);
    });
  }

  function injectPageProbe() {
    function pageProbeMain() {
      'use strict';

      if (window.__afloatNeteaseLyricsProbeInstalled)
        return;
      window.__afloatNeteaseLyricsProbeInstalled = true;

      const MESSAGE_TYPE = 'afloat-netease-lyrics-state';
      const EVENT_TYPE = 'afloat-netease-lyrics-state-event';
      const state = {
        songId: '',
        title: '',
        artist: '',
        playbackState: 'stopped',
        durationMs: 0,
        positionMs: 0,
        rawLyric: '',
        translatedLyric: '',
      };
      const audioSet = new Set();
      let lastSignature = '';
      let latestLyricRequestId = '';

      function normalizeText(value) {
        return value == null ? '' : String(value).trim();
      }

      function clampInt(value) {
        const parsed = Number(value);
        if (!Number.isFinite(parsed))
          return 0;
        return Math.max(0, Math.round(parsed));
      }

      function emitState() {
        const payload = {
          songId: normalizeText(state.songId),
          title: normalizeText(state.title),
          artist: normalizeText(state.artist),
          playbackState: normalizeText(state.playbackState) || 'stopped',
          durationMs: clampInt(state.durationMs),
          positionMs: clampInt(state.positionMs),
          rawLyric: normalizeText(state.rawLyric),
          translatedLyric: normalizeText(state.translatedLyric),
        };

        const signature = [
          payload.songId,
          payload.title,
          payload.artist,
          payload.playbackState,
          payload.positionMs,
          payload.durationMs,
          payload.rawLyric,
          payload.translatedLyric,
        ].join('|');

        if (signature === lastSignature)
          return;

        lastSignature = signature;
        window.postMessage({ type: MESSAGE_TYPE, payload }, '*');
        document.dispatchEvent(new CustomEvent(EVENT_TYPE, {
          detail: payload,
        }));
      }

      function trackKey(songId, title, artist) {
        const normalizedSongId = normalizeText(songId);
        if (normalizedSongId)
          return normalizedSongId;

        const normalizedTitle = normalizeText(title);
        const normalizedArtist = normalizeText(artist);
        if (!normalizedTitle && !normalizedArtist)
          return '';

        return `${normalizedTitle}|${normalizedArtist}`;
      }

      function lyricRequestSongId(requestUrl) {
        const urlMatch = /[?&]id=(\d+)/.exec(requestUrl || '');
        return urlMatch && urlMatch[1] ? urlMatch[1] : '';
      }

      function isLyricRequest(requestUrl) {
        return /\/lyric(?:\/v\d+)?(?:\?|$)/.test(requestUrl || '');
      }

      function shouldInvalidateLyrics(nextSongId, nextTitle, nextArtist) {
        const previousSongId = normalizeText(state.songId);
        const previousMetadataKey = trackKey('', state.title, state.artist);
        const resolvedSongId = normalizeText(nextSongId) || previousSongId;
        const resolvedMetadataKey = trackKey('', nextTitle || state.title, nextArtist || state.artist);

        if (previousSongId && resolvedSongId && previousSongId !== resolvedSongId)
          return true;
        if (!previousMetadataKey || !resolvedMetadataKey || previousMetadataKey === resolvedMetadataKey)
          return false;

        return !nextSongId || previousSongId === resolvedSongId;
      }

      function invalidateLyricsForSession(nextSongId) {
        latestLyricRequestId = '';
        if (!nextSongId)
          state.songId = '';
        state.rawLyric = '';
        state.translatedLyric = '';
      }

      function mergeTrack(track) {
        if (!track || typeof track !== 'object')
          return false;

        let changed = false;
        const previousTrackKey = trackKey(state.songId, state.title, state.artist);
        const nextSongId = normalizeText(track.id || track.songId);
        const nextTitle = normalizeText(track.name || track.title);
        let nextArtist = normalizeText(track.artist);

        if (Array.isArray(track.ar))
          nextArtist = track.ar.map((item) => normalizeText(item && item.name)).filter(Boolean).join(', ');
        else if (Array.isArray(track.artists))
          nextArtist = track.artists.map((item) => normalizeText(item && item.name)).filter(Boolean).join(', ');

        if (shouldInvalidateLyrics(nextSongId, nextTitle, nextArtist)) {
          invalidateLyricsForSession(nextSongId);
          changed = true;
        }

        if (nextSongId && nextSongId !== state.songId) {
          state.songId = nextSongId;
          changed = true;
        }
        if (nextTitle && nextTitle !== state.title) {
          state.title = nextTitle;
          changed = true;
        }
        if (nextArtist && nextArtist !== state.artist) {
          state.artist = nextArtist;
          changed = true;
        }

        const nextTrackKey = trackKey(nextSongId || state.songId, nextTitle || state.title, nextArtist || state.artist);
        if (previousTrackKey && nextTrackKey && previousTrackKey !== nextTrackKey) {
          invalidateLyricsForSession(nextSongId);
          changed = true;
        }

        return changed;
      }

      function mergeLyricPayload(data, requestUrl) {
        if (!data || typeof data !== 'object')
          return false;

        let changed = false;
        const requestSongId = lyricRequestSongId(requestUrl);
        const lyricText = normalizeText((data.lrc && data.lrc.lyric) || data.rawLyric || data.lyric);
        const translatedText = normalizeText(
          (data.tlyric && typeof data.tlyric.lyric === 'string' ? data.tlyric.lyric : '') ||
          (typeof data.translatedLyric === 'string' ? data.translatedLyric : '')
        );

        if (requestSongId && latestLyricRequestId && requestSongId !== latestLyricRequestId)
          return false;

        if (lyricText && lyricText !== state.rawLyric) {
          state.rawLyric = lyricText;
          changed = true;
        }
        if (translatedText && translatedText !== state.translatedLyric) {
          state.translatedLyric = translatedText;
          changed = true;
        }
        if (requestSongId && requestSongId !== state.songId) {
          state.songId = requestSongId;
          changed = true;
        }

        return changed;
      }

      function mergeMediaSession() {
        const session = navigator.mediaSession;
        if (!session)
          return false;

        let changed = false;
        const metadata = session.metadata;
        if (metadata) {
          const nextTitle = normalizeText(metadata.title);
          const nextArtist = normalizeText(metadata.artist);
          if (shouldInvalidateLyrics('', nextTitle, nextArtist)) {
            invalidateLyricsForSession('');
            changed = true;
          }
          if (nextTitle && nextTitle !== state.title) {
            state.title = nextTitle;
            changed = true;
          }
          if (nextArtist && nextArtist !== state.artist) {
            state.artist = nextArtist;
            changed = true;
          }
        }

        const nextPlaybackState = normalizeText(session.playbackState);
        if (nextPlaybackState && nextPlaybackState !== 'none' && nextPlaybackState !== state.playbackState) {
          state.playbackState = nextPlaybackState;
          changed = true;
        }

        return changed;
      }

      function mergePositionState(positionState) {
        if (!positionState || typeof positionState !== 'object')
          return false;

        let changed = false;
        const durationMs = Math.max(0, Math.round(Number(positionState.duration || 0) * 1000));
        const positionMs = Math.max(0, Math.round(Number(positionState.position || 0) * 1000));

        if (durationMs !== state.durationMs) {
          state.durationMs = durationMs;
          changed = true;
        }
        if (positionMs !== state.positionMs) {
          state.positionMs = positionMs;
          changed = true;
        }

        return changed;
      }

      function candidateAudios() {
        const discovered = Array.from(document.querySelectorAll('audio'));
        for (const audio of discovered)
          audioSet.add(audio);
        return Array.from(audioSet);
      }

      function audioScore(audio) {
        if (!audio || typeof audio.currentTime !== 'number')
          return -1;

        let score = 0;
        if (!audio.paused)
          score += 1000;
        if (Number.isFinite(audio.duration) && audio.duration > 0)
          score += 100;
        if (Number.isFinite(audio.currentTime) && audio.currentTime > 0)
          score += 10;
        if (Number.isFinite(audio.readyState) && audio.readyState > 0)
          score += audio.readyState;
        if (audio.ended)
          score -= 100;
        return score;
      }

      function mergeAudioState() {
        const audios = candidateAudios();
        let activeAudio = null;
        let bestScore = -1;

        for (const audio of audios) {
          const score = audioScore(audio);
          if (score <= bestScore)
            continue;

          bestScore = score;
          activeAudio = audio;
        }

        if (!activeAudio || bestScore < 0)
          return false;

        let changed = false;
        const durationMs = Number.isFinite(activeAudio.duration) ? Math.max(0, Math.round(activeAudio.duration * 1000)) : 0;
        const positionMs = Number.isFinite(activeAudio.currentTime) ? Math.max(0, Math.round(activeAudio.currentTime * 1000)) : 0;
        const playbackState = activeAudio.paused ? 'paused' : 'playing';

        if (durationMs !== state.durationMs) {
          state.durationMs = durationMs;
          changed = true;
        }
        if (positionMs !== state.positionMs) {
          state.positionMs = positionMs;
          changed = true;
        }
        if (playbackState !== state.playbackState) {
          state.playbackState = playbackState;
          changed = true;
        }

        return changed;
      }

      function inspectPayload(data, requestUrl) {
        let changed = false;
        if (!data || typeof data !== 'object')
          return false;

        if (Array.isArray(data.songs)) {
          for (const song of data.songs)
            changed = mergeTrack(song) || changed;
        }
        if (data.song && typeof data.song === 'object')
          changed = mergeTrack(data.song) || changed;
        if (data.currentSong && typeof data.currentSong === 'object')
          changed = mergeTrack(data.currentSong) || changed;
        if (data.currentTrack && typeof data.currentTrack === 'object')
          changed = mergeTrack(data.currentTrack) || changed;
        if (data.data && !Array.isArray(data.data) && typeof data.data === 'object')
          changed = mergeTrack(data.data) || changed;

        if (isLyricRequest(requestUrl))
          changed = mergeLyricPayload(data, requestUrl) || changed;

        if (changed)
          emitState();

        return changed;
      }

      function parseJsonSafely(text) {
        try {
          return JSON.parse(text);
        } catch (_) {
          return null;
        }
      }

      const originalSetPositionState = navigator.mediaSession && typeof navigator.mediaSession.setPositionState === 'function'
        ? navigator.mediaSession.setPositionState.bind(navigator.mediaSession)
        : null;
      if (originalSetPositionState) {
        navigator.mediaSession.setPositionState = function patchedSetPositionState(positionState) {
          const changed = mergePositionState(positionState);
          if (changed)
            emitState();
          return originalSetPositionState(positionState);
        };
      }

      const OriginalAudio = window.Audio;
      if (typeof OriginalAudio === 'function') {
        window.Audio = function AfloatAudioProxy(...args) {
          const audio = new OriginalAudio(...args);
          audioSet.add(audio);
          return audio;
        };
        window.Audio.prototype = OriginalAudio.prototype;
        Object.setPrototypeOf(window.Audio, OriginalAudio);
      }

      const originalCreateElement = Document.prototype.createElement;
      Document.prototype.createElement = function patchedCreateElement(tagName, options) {
        const element = originalCreateElement.call(this, tagName, options);
        if (String(tagName).toLowerCase() === 'audio')
          audioSet.add(element);
        return element;
      };

      const mediaEvents = ['play', 'pause', 'timeupdate', 'loadedmetadata', 'durationchange', 'seeked', 'emptied'];
      for (const eventName of mediaEvents) {
        window.addEventListener(eventName, (event) => {
          const target = event && event.target;
          if (!target || target.tagName !== 'AUDIO')
            return;

          audioSet.add(target);
          const sessionChanged = mergeMediaSession();
          const audioChanged = mergeAudioState();
          if (sessionChanged || audioChanged)
            emitState();
        }, true);
      }

      const originalFetch = window.fetch;
      if (typeof originalFetch === 'function') {
        window.fetch = async function patchedFetch(input, init) {
          const requestUrl = typeof input === 'string' ? input : (input && input.url) || '';
          const response = await originalFetch.call(this, input, init);
          try {
            const clone = response.clone();
            const contentType = clone.headers.get('content-type') || '';
            if (contentType.includes('application/json') || /\/api\//.test(requestUrl) || /\/weapi\//.test(requestUrl)) {
              const data = parseJsonSafely(await clone.text());
              if (data)
                inspectPayload(data, requestUrl);
            }
          } catch (_) {
          }
          return response;
        };
      }

      const originalOpen = XMLHttpRequest.prototype.open;
      const originalSend = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.open = function patchedOpen(method, requestUrl, ...rest) {
        this.__afloatRequestUrl = requestUrl;
        return originalOpen.call(this, method, requestUrl, ...rest);
      };
      XMLHttpRequest.prototype.send = function patchedSend(body) {
        this.addEventListener('load', function onLoad() {
          try {
            const requestUrl = this.__afloatRequestUrl || this.responseURL || '';
            const contentType = this.getResponseHeader('content-type') || '';
            if (!contentType.includes('application/json') && !/\/api\//.test(requestUrl) && !/\/weapi\//.test(requestUrl))
              return;

            const data = parseJsonSafely(typeof this.responseText === 'string' ? this.responseText : '');
            if (data)
              inspectPayload(data, requestUrl);
          } catch (_) {
          }
        });
        return originalSend.call(this, body);
      };

      setInterval(() => {
        const sessionChanged = mergeMediaSession();
        const audioChanged = mergeAudioState();
        if (sessionChanged || audioChanged)
          emitState();
      }, 1000);
    }

    const source = `(${pageProbeMain.toString()})();`;

    function appendProbeScript() {
      const parent = document.documentElement || document.head || document.body;
      if (!parent)
        return false;

      if (typeof GM_addElement === 'function') {
        try {
          GM_addElement(parent, 'script', { textContent: source });
          return true;
        } catch (_) {
        }
      }

      const script = document.createElement('script');
      script.textContent = source;
      parent.appendChild(script);
      script.remove();
      return true;
    }

    if (appendProbeScript())
      return;

    const retryInjection = () => {
      if (appendProbeScript()) {
        document.removeEventListener('readystatechange', retryInjection, true);
        document.removeEventListener('DOMContentLoaded', retryInjection, true);
      }
    };

    document.addEventListener('readystatechange', retryInjection, true);
    document.addEventListener('DOMContentLoaded', retryInjection, true);
  }

  function handleIncomingPayload(payload, source) {
    debugLog('page:' + source, {
      hasPayload: !!payload,
      type: payload && payload.type ? String(payload.type) : '',
    });
    handleStateMessage(payload);
  }

  window.addEventListener('message', (event) => {
    if (event.source !== window)
      return;

    const payload = event.data;
    if (!payload || payload.type !== MESSAGE_TYPE)
      return;

    handleIncomingPayload(payload.payload, 'postMessage');
  }, false);

  document.addEventListener(EVENT_TYPE, (event) => {
    const detail = event && event.detail;
    if (!detail || typeof detail !== 'object')
      return;

    handleIncomingPayload(detail, 'customEvent');
  }, false);

  injectPageProbe();
})();
