(function () {
  'use strict';

  const BRIDGE_URL = 'http://127.0.0.1:18765/push';
  const LYRIC_API_PREFIX = 'https://music.163.com/api/song/lyric?id=';
  const SEARCH_API_PREFIX = 'https://music.163.com/api/search/get/web?csrf_token=&type=1&offset=0&total=true&limit=10&s=';
  const lyricCache = new Map();
  const songIdLookupCache = new Map();
  const frameStateCache = new Map();
  const pendingSongIdByFrame = new Map();
  const pendingLookupKeyByFrame = new Map();
  const activeSessionByTab = new Map();
  let lastForwardedSignature = '';
  let lastDebugSignature = '';
  const debugLogReasons = new Set([
    'skipStaleSongIdLookup',
    'skipStaleSongIdLookupLyrics',
    'skipStaleFetchLyrics',
  ]);

  function frameKey(sender) {
    const tabId = sender && sender.tab && Number.isInteger(sender.tab.id) ? sender.tab.id : -1;
    const frameId = sender && Number.isInteger(sender.frameId) ? sender.frameId : 0;
    return `${tabId}:${frameId}`;
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

  function payloadScore(payload) {
    let score = 0;
    const title = payload.title == null ? '' : String(payload.title).trim();

    if (payload.songId)
      score += 1000;
    if (payload.rawLyric)
      score += 1000;
    if (payload.translatedLyric)
      score += 200;
    if (payload.durationMs > 0)
      score += 250;
    if (payload.positionMs > 0)
      score += 100;
    if (payload.playbackState === 'playing')
      score += 120;
    else if (payload.playbackState === 'paused')
      score += 60;
    if (payload.artist)
      score += 20;
    if (title)
      score += 10;
    if (/^__.*__$/.test(title))
      score -= 4000;
    if (!payload.songId && !payload.rawLyric && payload.durationMs === 0 && payload.positionMs === 0)
      score -= 500;

    return score;
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
    } else if (songTitle !== payloadTitle) {
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

    logSelection('searchSongIdStart', {
      lookupKey,
      query,
      payload: summarizePayload(payload),
    });

    const searchPromise = fetch(SEARCH_API_PREFIX + encodeURIComponent(query), {
      credentials: 'omit',
      mode: 'cors'
    })
      .then((response) => response.ok ? response.json() : {})
      .then((data) => {
        const songId = bestSongIdFromSearch(data, payload);
        logSelection('searchSongIdResult', {
          lookupKey,
          query,
          songId,
        });
        return songId;
      })
      .catch(() => '')
      .then((songId) => {
        const resolvedPromise = Promise.resolve(songId);
        songIdLookupCache.set(lookupKey, resolvedPromise);
        return songId;
      });

    songIdLookupCache.set(lookupKey, searchPromise);
    return searchPromise;
  }

  function pruneFrameStateCache() {
    const cutoff = Date.now() - 5000;
    for (const [key, entry] of frameStateCache.entries()) {
      if (!entry || entry.updatedAt < cutoff)
        frameStateCache.delete(key);
    }
  }

  function updateFrameState(sender, payload) {
    const tabId = sender && sender.tab && Number.isInteger(sender.tab.id) ? sender.tab.id : -1;
    const payloadSessionLabel = sessionLabel(payload);
    if (tabId >= 0 && payload.songId && payloadSessionLabel)
      activeSessionByTab.set(tabId, {
        sessionLabel: payloadSessionLabel,
        songId: payload.songId,
      });

    frameStateCache.set(frameKey(sender), {
      tabId,
      frameId: sender && Number.isInteger(sender.frameId) ? sender.frameId : 0,
      payload,
      updatedAt: Date.now(),
    });
  }

  function sessionLabel(payload) {
    if (!payload || typeof payload !== 'object')
      return '';

    const songId = payload.songId == null ? '' : String(payload.songId).trim();
    if (songId)
      return `id:${songId}`;

    const title = payload.title == null ? '' : String(payload.title).trim();
    const artist = payload.artist == null ? '' : String(payload.artist).trim();
    if (!title && !artist)
      return '';

    return `meta:${title}|${artist}`;
  }

  function sameSession(leftPayload, rightPayload) {
    const leftSongId = leftPayload && leftPayload.songId ? String(leftPayload.songId).trim() : '';
    const rightSongId = rightPayload && rightPayload.songId ? String(rightPayload.songId).trim() : '';
    if (leftSongId && rightSongId)
      return leftSongId === rightSongId;

    const leftTitle = leftPayload && leftPayload.title ? String(leftPayload.title).trim() : '';
    const leftArtist = leftPayload && leftPayload.artist ? String(leftPayload.artist).trim() : '';
    const rightTitle = rightPayload && rightPayload.title ? String(rightPayload.title).trim() : '';
    const rightArtist = rightPayload && rightPayload.artist ? String(rightPayload.artist).trim() : '';
    if (!leftTitle && !leftArtist)
      return false;
    if (!rightTitle && !rightArtist)
      return false;

    return leftTitle === rightTitle && leftArtist === rightArtist;
  }

  function timelineScore(payload) {
    let score = 0;
    if (!payload)
      return score;

    if (payload.playbackState === 'playing')
      score += 2000;
    else if (payload.playbackState === 'paused')
      score += 1000;
    if (payload.durationMs > 0)
      score += 800;
    if (payload.positionMs > 0)
      score += 600;
    if (payload.songId)
      score += 150;
    if (payload.title)
      score += 40;
    if (payload.artist)
      score += 20;
    if (/^__.*__$/.test(payload.title || ''))
      score -= 4000;

    return score;
  }

  function lyricsScore(payload) {
    let score = 0;
    if (!payload)
      return score;

    if (payload.rawLyric)
      score += 2000;
    if (payload.translatedLyric)
      score += 300;
    if (payload.songId)
      score += 120;
    if (payload.title)
      score += 20;
    if (payload.artist)
      score += 10;
    if (/^__.*__$/.test(payload.title || ''))
      score -= 4000;

    return score;
  }

  function preferEntry(candidate, current, scoreFn) {
    if (!candidate)
      return current;
    if (!current)
      return candidate;

    const candidateScore = scoreFn(candidate.payload);
    const currentScore = scoreFn(current.payload);
    if (candidateScore !== currentScore)
      return candidateScore > currentScore ? candidate : current;

    return candidate.updatedAt > current.updatedAt ? candidate : current;
  }

  function summarizeEntry(entry) {
    if (!entry)
      return null;

    return {
      tabId: entry.tabId,
      frameId: entry.frameId,
      songId: entry.payload.songId,
      title: entry.payload.title,
      artist: entry.payload.artist,
      playbackState: entry.payload.playbackState,
      positionMs: entry.payload.positionMs,
      durationMs: entry.payload.durationMs,
      hasRawLyric: !!entry.payload.rawLyric,
      hasTranslatedLyric: !!entry.payload.translatedLyric,
      sessionLabel: sessionLabel(entry.payload),
      payloadScore: payloadScore(entry.payload),
      timelineScore: timelineScore(entry.payload),
      lyricsScore: lyricsScore(entry.payload),
      updatedAt: entry.updatedAt,
    };
  }

  function summarizePayload(payload) {
    if (!payload)
      return null;

    return {
      songId: payload.songId,
      title: payload.title,
      artist: payload.artist,
      playbackState: payload.playbackState,
      positionMs: payload.positionMs,
      durationMs: payload.durationMs,
      hasRawLyric: !!payload.rawLyric,
      hasTranslatedLyric: !!payload.translatedLyric,
      sessionLabel: sessionLabel(payload),
      payloadScore: payloadScore(payload),
      timelineScore: timelineScore(payload),
      lyricsScore: lyricsScore(payload),
    };
  }

  function logSelection(reason, details) {
    if (!debugLogReasons.has(reason))
      return;

    const signature = JSON.stringify({ reason, details });
    if (signature === lastDebugSignature)
      return;

    lastDebugSignature = signature;
    console.log('[DymicShell:NeteaseLyricsDebug]', reason, details);
  }

  function selectBestPayload() {
    pruneFrameStateCache();

    const entries = Array.from(frameStateCache.values());
    if (entries.length === 0)
      return null;

    let bestTimelineEntry = null;
    for (const entry of entries)
      bestTimelineEntry = preferEntry(entry, bestTimelineEntry, timelineScore);

    if (!bestTimelineEntry)
      return null;

    const mergedPayload = {
      ...bestTimelineEntry.payload,
    };
    const baseSessionLabel = sessionLabel(bestTimelineEntry.payload);
    const activeSession = activeSessionByTab.get(bestTimelineEntry.tabId) || null;
    let sessionSongId = '';
    let bestLyricsEntry = null;

    for (const entry of entries) {
      if (entry.tabId !== bestTimelineEntry.tabId)
        continue;
      if (baseSessionLabel !== '' && !sameSession(entry.payload, bestTimelineEntry.payload))
        continue;

      if (!sessionSongId && entry.payload.songId)
        sessionSongId = entry.payload.songId;

      bestLyricsEntry = preferEntry(entry, bestLyricsEntry, lyricsScore);
    }

    if (!sessionSongId && activeSession && activeSession.sessionLabel === baseSessionLabel)
      sessionSongId = activeSession.songId;

    if (!mergedPayload.songId && sessionSongId)
      mergedPayload.songId = sessionSongId;

    if (bestLyricsEntry) {
      if (bestLyricsEntry.payload.songId)
        mergedPayload.songId = bestLyricsEntry.payload.songId;
      if (bestLyricsEntry.payload.title)
        mergedPayload.title = bestLyricsEntry.payload.title;
      if (bestLyricsEntry.payload.artist)
        mergedPayload.artist = bestLyricsEntry.payload.artist;
      if (bestLyricsEntry.payload.rawLyric)
        mergedPayload.rawLyric = bestLyricsEntry.payload.rawLyric;
      if (bestLyricsEntry.payload.translatedLyric)
        mergedPayload.translatedLyric = bestLyricsEntry.payload.translatedLyric;
    }

    logSelection('selectBestPayload', {
      entryCount: entries.length,
      baseSessionLabel,
      activeSession,
      timelineEntry: summarizeEntry(bestTimelineEntry),
      lyricsEntry: summarizeEntry(bestLyricsEntry),
      mergedPayload: summarizePayload(mergedPayload),
    });

    return {
      payload: mergedPayload,
      timelineEntry: bestTimelineEntry,
      lyricsEntry: bestLyricsEntry,
      activeSongId: sessionSongId,
    };
  }

  function pushBestPayload() {
    const selection = selectBestPayload();
    if (!selection)
      return Promise.resolve({ ok: false, ignored: true });

    const bestPayload = selection.payload;

    logSelection('pushBestPayload', {
      activeSongId: selection.activeSongId,
      timelineEntry: summarizeEntry(selection.timelineEntry),
      lyricsEntry: summarizeEntry(selection.lyricsEntry),
      mergedPayload: summarizePayload(bestPayload),
    });

    const signature = payloadSignature(bestPayload);
    if (signature === lastForwardedSignature) {
      logSelection('pushBestPayloadSkipped', {
        reason: 'duplicate-forwarded-signature',
        mergedPayload: summarizePayload(bestPayload),
      });
      return Promise.resolve({ ok: true, skipped: true });
    }

    lastForwardedSignature = signature;
    return pushToBridge(bestPayload);
  }

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

  browser.runtime.onMessage.addListener((message, sender) => {
    if (!message || message.type !== 'dymicshell-netease-lyrics-push')
      return Promise.resolve({ ok: false, ignored: true });

    const payload = normalizePayload(message.payload);
    const senderStateKey = frameKey(sender);
    const requestedSongId = payload.songId;
    const lookupKey = lookupKeyForPayload(payload);
    const shouldLookupSongId = payload.songId === ''
      && payload.rawLyric === ''
      && payload.translatedLyric === ''
      && lookupKey !== '';

    logSelection('incomingPayload', {
      senderStateKey,
      requestedSongId,
      payload: summarizePayload(payload),
      lookupKey,
      commitMode: payload.rawLyric !== '' || payload.translatedLyric !== ''
        ? 'direct'
        : (payload.songId !== ''
            ? 'fetchLyrics'
            : (shouldLookupSongId ? 'lookupSongId' : 'direct')),
    });

    if (requestedSongId)
      pendingSongIdByFrame.set(senderStateKey, requestedSongId);
    if (lookupKey)
      pendingLookupKeyByFrame.set(senderStateKey, lookupKey);
    else
      pendingLookupKeyByFrame.delete(senderStateKey);

    const commitPayload = (resolvedPayload) => {
      if (resolvedPayload.songId)
        pendingSongIdByFrame.set(senderStateKey, resolvedPayload.songId);
      updateFrameState(sender, resolvedPayload);
      return pushBestPayload();
    };

    if (payload.rawLyric !== '' || payload.translatedLyric !== '')
      return commitPayload(payload);

    if (payload.songId === '') {
      if (!shouldLookupSongId)
        return commitPayload(payload);

      return commitPayload(payload).then(() => searchSongIdByMetadata(payload).then((resolvedSongId) => {
        if (pendingLookupKeyByFrame.get(senderStateKey) !== lookupKey) {
          logSelection('skipStaleSongIdLookup', {
            senderStateKey,
            lookupKey,
            currentLookupKey: pendingLookupKeyByFrame.get(senderStateKey) || '',
            payload: summarizePayload(payload),
          });
          return { ok: true, skipped: true };
        }

        if (!resolvedSongId)
          return { ok: true, skipped: true, unresolved: true };

        return fetchLyrics(resolvedSongId).then((lyrics) => {
          if (pendingLookupKeyByFrame.get(senderStateKey) !== lookupKey) {
            logSelection('skipStaleSongIdLookupLyrics', {
              senderStateKey,
              lookupKey,
              currentLookupKey: pendingLookupKeyByFrame.get(senderStateKey) || '',
              resolvedSongId,
            });
            return { ok: true, skipped: true };
          }

          return commitPayload({
            ...payload,
            songId: resolvedSongId,
            rawLyric: lyrics.rawLyric || payload.rawLyric,
            translatedLyric: lyrics.translatedLyric || payload.translatedLyric,
          });
        });
      }));
    }

    return fetchLyrics(payload.songId).then((lyrics) => {
      if (requestedSongId && pendingSongIdByFrame.get(senderStateKey) !== requestedSongId) {
        logSelection('skipStaleFetchLyrics', {
          senderStateKey,
          requestedSongId,
          currentPendingSongId: pendingSongIdByFrame.get(senderStateKey) || '',
          payload: {
            songId: payload.songId,
            title: payload.title,
            artist: payload.artist,
            playbackState: payload.playbackState,
            positionMs: payload.positionMs,
            durationMs: payload.durationMs,
          },
        });
        return { ok: true, skipped: true };
      }

      return commitPayload({
        ...payload,
        rawLyric: lyrics.rawLyric || payload.rawLyric,
        translatedLyric: lyrics.translatedLyric || payload.translatedLyric,
      });
    });
  });
})();
