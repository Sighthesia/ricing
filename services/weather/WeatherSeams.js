.pragma library

// Test seams for WeatherService, both inert in production.
//
// They exist because a root-level harness shares one process with the
// singleton, so it cannot give the service a different cache directory or a
// different network stack from the outside: the singleton is constructed on
// first use, reads the real Quickshell.cacheDir, and would reach the real
// Open-Meteo endpoint. These two variables are how a harness takes both over
// without changing how the service is built.
//
// They live in their own module rather than in WeatherLogic.js so that module
// stays stateless and runnable under a bare qmltestrunner.
//
// cachePathOverride: read once, when the singleton is constructed, to choose
//   where the persisted reading lives. Empty means "use Quickshell.cacheDir",
//   which is the only value production ever sees. A harness points it at a
//   throwaway file before its first reference to the service, so the run
//   neither reads the desktop's real cache (which would make its assertions
//   depend on what the user last fetched) nor writes one.
//
// transport: the function refresh() sends a request through instead of
//   building an XMLHttpRequest. Called as transport(url) and expected to answer
//   with { status, body, now } — the same shape the real request handler
//   produces, so the response path under test is the production one and not a
//   copy of it. `now` is optional and lets a test pin updatedAt exactly.
//   Null means "use XMLHttpRequest", which is the only value production sees.
var cachePathOverride = ""
var transport = null