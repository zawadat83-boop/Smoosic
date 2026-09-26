# Nuty fork of Smoosic

This fork (`zawadat83-boop/smoosic`) packages Smoosic as the staff-notation editor of the Nuty portal
(https://github.com/zawadat83-boop/nuty, see `docs/EDITOR.md` there). The portal runs on isolated
networks, so **nothing may be loaded from a CDN at runtime**.

## Branches

- `main` — mirror of upstream `Smoosic/smoosic` (sync with upstream, no Nuty changes).
- `nuty/*` — Nuty changes. Keep them small and upstream-friendly (configuration hooks instead of hard-coded edits).

## Build

CI (`.github/workflows/nuty-build.yml`) runs `tools/nuty/dist.sh` and uploads `nuty-smoosic-<version>.tar.gz`
with `SHA256SUMS`. Tags `nuty-v*` also create a GitHub release. The Nuty repo vendors the unpacked bundle into
`app/songs/static/songs/vendor/smoosic/<version>/`.

Local build (needs Node 20+ and network): `npm ci && tools/nuty/dist.sh`.

## Runtime configuration required in Nuty

Before starting the application, point audio and assets to local static paths:

```js
Smo.SuiSampleMedia.soundfontBaseUrl = STATIC + 'soundfonts/FluidR3_GM';
Smo.SuiSampleMedia.percussionUrl   = STATIC + 'soundfonts/percussion-ogg.js';
// pass libraryUrl: '' (or a local JSON) and hide the library menu in the ribbon layout
```

Load `jquery.slim.min.js`, `jszip.js` and `smoosic.js` from the local bundle, never from `code.jquery.com`.

## Nuty changes vs upstream

- `build/build.js`: `SMOOSIC_MODE=production` → minified bundle, external source map; non-zero exit only when the bundle is not emitted (upstream has pre-existing TS type errors in some `.vue` dialogs — reported as CI warnings, to be fixed separately).
- `src/render/audio/samples.ts`: configurable `soundfontBaseUrl` and `percussionUrl` (defaults unchanged).
