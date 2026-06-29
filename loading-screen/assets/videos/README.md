# Loading screen videos

Place your MP4/WebM loading screen videos in this folder on your webserver.

Expected filenames:

```text
memonetwork.mp4
gm_construct.mp4
gm_flatgrass.mp4
gm_bigcity.mp4
gm_fork.mp4
```

The loading screen automatically tries a map-specific video first. If no map-specific video exists, it falls back to `memonetwork.mp4`.

Recommended video settings:

- 1920x1080
- MP4 H.264
- 20-40 seconds
- muted/no audio
- loop-friendly
- compressed for web use

If a video is missing, the loading screen still works with the animated cinematic fallback background.
