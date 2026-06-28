# MemoNetwork Loading Screen

This folder contains the first MemoNetwork loading screen.

## How to use

Upload `index.html` to your website, for example:

```text
https://memocraft.nl/loading/index.html
```

Then add this to your Garry's Mod server config:

```cfg
sv_loadingurl "https://memocraft.nl/loading/index.html?steamid=%s&map=%m"
```

Restart the server after changing the config.

## Notes

- `%s` is replaced by the joining player's SteamID.
- `%m` is replaced by the current map.
- The loading screen is static HTML/CSS/JS, so it can run on simple web hosting.
- Keep the file publicly accessible, otherwise Garry's Mod clients cannot load it.
