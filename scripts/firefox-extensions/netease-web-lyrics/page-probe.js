(function () {
  'use strict';

  if (window.__dymicshellNeteaseLyricsProbeInstalled)
    return;
  window.__dymicshellNeteaseLyricsProbeInstalled = true;

  const MESSAGE_TYPE = 'dymicshell-netease-lyrics-state';
  const DEBUG_PREFIX = '[DymicShell:NeteaseLyricsDebug]';
  const DEBUG_ENABLED = !!window.__dymicshellNeteaseLyricsDebugEnabled;
  const state = {
    songId: '',
    title: '',
    artist: '',
    playbackState: 'stopped',
    durationMs: 0,
    positionMs: 0,
    rawLyric: '',
  };
  const audioSet = new Set();
  let lastSignature = '';
  let latestLyricRequestId = '';
  const lastDebugSignatureByReason = new Map();

  function normalizeText(value) {
    return value == null ? '' : String(value).trim();
  }

  function clampInt(value) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed))
      return 0;
    return Math.max(0, Math.round(parsed));
  }

  function summarizeStateSnapshot(payload) {
    const source = payload && typeof payload === 'object' ? payload : state;
    return {
      songId: normalizeText(source.songId),
      title: normalizeText(source.title),
      artist: normalizeText(source.artist),
      playbackState: normalizeText(source.playbackState) || 'stopped',
      positionMs: clampInt(source.positionMs),
      durationMs: clampInt(source.durationMs),
      hasRawLyric: !!normalizeText(source.rawLyric),
    };
  }

  function lyricEndpointLabel(requestUrl) {
    const match = /\/(lyric(?:\/v\d+)?)(?:\?|$)/.exec(requestUrl || '');
    return match && match[1] ? `/${match[1]}` : '';
  }

  function debugLog(reason, details) {
    if (!DEBUG_ENABLED)
      return;

    const signature = JSON.stringify(details || {});
    if (lastDebugSignatureByReason.get(reason) === signature)
      return;

    lastDebugSignatureByReason.set(reason, signature);
    console.info(DEBUG_PREFIX, reason, details || {});
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
    };

    const signature = [
      payload.songId,
      payload.title,
      payload.artist,
      payload.playbackState,
      payload.positionMs,
      payload.durationMs,
      payload.rawLyric,
    ].join('|');

    if (signature === lastSignature)
      return;

    lastSignature = signature;
    window.postMessage({
      type: MESSAGE_TYPE,
      payload,
    }, '*');
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

  function metadataKey(title, artist) {
    return trackKey('', title, artist);
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
    const previousMetadataKey = metadataKey(state.title, state.artist);
    const resolvedSongId = normalizeText(nextSongId) || previousSongId;
    const resolvedMetadataKey = metadataKey(nextTitle || state.title, nextArtist || state.artist);

    if (previousSongId && resolvedSongId && previousSongId !== resolvedSongId)
      return true;

    if (!previousMetadataKey || !resolvedMetadataKey || previousMetadataKey === resolvedMetadataKey)
      return false;

    return !nextSongId || previousSongId === resolvedSongId;
  }

  function invalidateLyricsForSession(nextSongId, reason, details) {
    const previousState = summarizeStateSnapshot();
    let changed = false;

    latestLyricRequestId = '';
    if (!nextSongId && state.songId !== '') {
      state.songId = '';
      changed = true;
    }
    if (state.rawLyric !== '') {
      state.rawLyric = '';
      changed = true;
    }

    debugLog('page:invalidateLyricsForSession', {
      reason: reason || 'unknown',
      changed,
      nextSongId: normalizeText(nextSongId),
      before: previousState,
      after: summarizeStateSnapshot(),
      details: details || {},
    });

    return changed;
  }

  function noteLyricRequest(requestUrl, source) {
    const requestSongId = lyricRequestSongId(requestUrl);
    if (requestSongId)
      latestLyricRequestId = requestSongId;

    debugLog('page:lyricRequestDetected', {
      source: normalizeText(source),
      endpoint: lyricEndpointLabel(requestUrl),
      requestSongId,
      latestLyricRequestId,
    });
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
      nextArtist = track.ar.map(item => normalizeText(item && item.name)).filter(Boolean).join(', ');
    else if (Array.isArray(track.artists))
      nextArtist = track.artists.map(item => normalizeText(item && item.name)).filter(Boolean).join(', ');

    if (shouldInvalidateLyrics(nextSongId, nextTitle, nextArtist)) {
      changed = invalidateLyricsForSession(nextSongId, 'mergeTrack:shouldInvalidateLyrics', {
        nextSongId,
        nextTitle,
        nextArtist,
      }) || changed;
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
      changed = invalidateLyricsForSession(nextSongId, 'mergeTrack:trackKeyChanged', {
        previousTrackKey,
        nextTrackKey,
        nextSongId,
      }) || changed;
    }

    return changed;
  }

  function mergeLyricPayload(data, requestUrl) {
    if (!data || typeof data !== 'object')
      return false;

    const beforeState = summarizeStateSnapshot();
    let changed = false;
    const requestSongId = lyricRequestSongId(requestUrl);
    const lyricText = normalizeText((data.lrc && data.lrc.lyric) || data.rawLyric || data.lyric);

    debugLog('page:mergeLyricPayload', {
      endpoint: lyricEndpointLabel(requestUrl),
      requestSongId,
      latestLyricRequestId,
      hasRequestSongId: !!requestSongId,
      hasRawLyric: !!lyricText,
      before: beforeState,
    });

    if (requestSongId && latestLyricRequestId && requestSongId !== latestLyricRequestId) {
      debugLog('page:mergeLyricPayloadSkipped', {
        endpoint: lyricEndpointLabel(requestUrl),
        requestSongId,
        latestLyricRequestId,
        before: beforeState,
      });
      return false;
    }

    if (lyricText && lyricText !== state.rawLyric) {
      state.rawLyric = lyricText;
      changed = true;
    }

    if (requestSongId && requestSongId !== state.songId) {
      state.songId = requestSongId;
      changed = true;
    }

    debugLog('page:mergeLyricPayloadResult', {
      endpoint: lyricEndpointLabel(requestUrl),
      requestSongId,
      changed,
      after: summarizeStateSnapshot(),
    });

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
        changed = invalidateLyricsForSession('', 'mergeMediaSession:metadataChanged', {
          nextTitle,
          nextArtist,
        }) || changed;
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
    window.Audio = function DymicShellAudioProxy(...args) {
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
      const changed = sessionChanged || audioChanged;
      if (changed)
        emitState();
    }, true);
  }

  const originalFetch = window.fetch;
  if (typeof originalFetch === 'function') {
    window.fetch = async function patchedFetch(input, init) {
      const requestUrl = typeof input === 'string' ? input : (input && input.url) || '';
      if (isLyricRequest(requestUrl))
        noteLyricRequest(requestUrl, 'fetch');

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
    this.__dymicshellRequestUrl = requestUrl;
    if (isLyricRequest(requestUrl))
      noteLyricRequest(requestUrl, 'xhr');
    return originalOpen.call(this, method, requestUrl, ...rest);
  };
  XMLHttpRequest.prototype.send = function patchedSend(body) {
    this.addEventListener('load', function onLoad() {
      try {
        const requestUrl = this.__dymicshellRequestUrl || this.responseURL || '';
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
    const changed = sessionChanged || audioChanged;
    if (changed)
      emitState();
  }, 1000);
})();
