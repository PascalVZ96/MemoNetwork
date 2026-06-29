# MemoNetwork Cinematic Loading Screen

This folder contains the MemoNetwork cinematic loading screen.

## How to use

Upload the full `loading-screen` folder to your website, for example:

```text
https://memocraft.nl/loading/index.html
https://memocraft.nl/loading/config.json
https://memocraft.nl/loading/assets/videos/memonetwork.mp4
```

Then add this to your Garry's Mod server config:

```cfg
sv_loadingurl "https://memocraft.nl/loading/index.html?steamid=%s&map=%m"
```

Restart the server after changing the config.

## Video support

The loading screen tries to play a map-specific video first:

```text
assets/videos/gm_construct.mp4
assets/videos/gm_flatgrass.mp4
assets/videos/gm_bigcity.mp4
assets/videos/gm_fork.mp4
```

If no map-specific video exists, it falls back to:

```text
assets/videos/memonetwork.mp4
```

If no video exists at all, the page still works with an animated cinematic background.

## Player name

Garry's Mod does not always expose the player's name to the loading page. The screen now prefers `GameDetails.playerName` when available. If the game only sends a SteamID, it shows `Steam Player` instead of raw numbers.

## Recommended video settings

- 1920x1080
- MP4 H.264
- 20-40 seconds
- muted/no audio
- loop-friendly
- compressed for web use
