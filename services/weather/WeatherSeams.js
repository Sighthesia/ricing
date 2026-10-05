.pragma library

// Override points for WeatherService, both inert in production.
//
// They exist because the service is a singleton constructed on first use, so
// an embedder sharing that process cannot hand it a different cache directory
// or a different network stack from the outside: the service reads the real
// Quickshell.cacheDir and would reach the real Open-Meteo endpoint. Setting
// these two variables takes both over without changing how the service is
// built.
//
// They live in their own module rather than in WeatherLogic.js so that module
// stays stateless and loadable on its own.
//
// cachePathOverride: read once, when the singleton is constructed, to choose
//   where the persisted reading lives. Empty means "use Quickshell.cacheDir",
//   which is the only value production ever sees. An embedder points it at a
//   throwaway file before its first reference to the service, so the run
//   neither reads the desktop's real cache nor writes one.
//
// transport: the function refresh() sends a request through instead of
//   building an XMLHttpRequest. Called as transport(url) and expected to answer
//   with { status, body, now } — the same shape the real request handler
//   produces, so the response path that gets exercised is the production one
//   and not a copy of it. `now` is optional and pins updatedAt exactly.
//   Null means "use XMLHttpRequest", which is the only value production sees.
var cachePathOverride = ""
var transport = null