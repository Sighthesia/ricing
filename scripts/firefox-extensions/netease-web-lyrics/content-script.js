(function () {
  'use strict';

  const MESSAGE_TYPE = 'dymicshell-netease-lyrics-state';
  let lastSignature = '';

  function normalizePayload(rawPayload) {
    const payload = rawPayload && typeof rawPayload === 'object' ? rawPayload : {};
    const songId = payload.songId == null ? '' : String(payload.songId).trim();
    const title = payload.title == null ? '' : String(payload.title).trim();
    const artist = payload.artist == null ? '' : String(payload.artist).trim();
    const playbackState = payload.playbackState == null ? 'stopped' : String(payload.playbackState).trim() || 'stopped';
    const durationMs = Number.isFinite(Number(payload.durationMs)) ? Math.max(0, Math.round(Number(payload.durationMs))) : 0;
    const positionMs = Number.isFinite(Number(payload.positionMs)) ? Math.max(0, Math.round(Number(payload.positionMs))) : 0;
    const progress = durationMs > 0 ? Math.max(0, Math.min(1, positionMs / durationMs)) : 0;
    const rawLyric = payload.rawLyric == null ? '' : String(payload.rawLyric).trim();

    return {
      songId,
      title,
      artist,
      playbackState,
      durationMs,
      positionMs,
      progress,
      rawLyric,
    };
  }

  function pushToBridge(payload) {
    const normalized = normalizePayload(payload);
    const signature = [
      normalized.songId,
      normalized.title,
      normalized.artist,
      normalized.playbackState,
      normalized.positionMs,
      normalized.durationMs,
      normalized.rawLyric,
    ].join('|');

    if (signature === lastSignature)
      return;

    lastSignature = signature;
    browser.runtime.sendMessage({
      type: 'dymicshell-netease-lyrics-push',
      payload: normalized,
    }).catch(() => {});
  }

  window.addEventListener('message', (event) => {
    if (event.source !== window)
      return;

    const payload = event.data;
    if (!payload || payload.type !== MESSAGE_TYPE)
      return;

    pushToBridge(payload.payload);
  }, false);

  fetch(browser.runtime.getURL('page-probe.js'))
    .then((response) => response.text())
    .then((source) => {
      const wrappedWindow = window.wrappedJSObject;
      if (wrappedWindow && typeof wrappedWindow.eval === 'function') {
        wrappedWindow.eval(source);
        return;
      }

      const script = document.createElement('script');
      script.textContent = source;
      (document.head || document.documentElement).appendChild(script);
      script.remove();
    })
    .catch(() => {});
})();
