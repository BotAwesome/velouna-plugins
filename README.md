# Velouna plugins

The official plugins of [Velouna](https://github.com/BotAwesome/velouna), the media player.
Velouna ships with this repo already added: open **Settings → Extensions → Catalog**, tick what you want and choose **Install selected**.

| Plugin | Kind | What it does |
|---|---|---|
| [Velounizer](plugins/velounizer) | Visualizer | Ink, Aurora and Contour: pictures that follow your music |

## More plugins

Anyone can publish plugins in a repo of their own, and you can add any repo to Velouna by its link under **Settings → Extensions → Repos**.

Want to write one? The examples and the documentation are in [example-plugins](https://github.com/BotAwesome/example-plugins): [your first visualizer](https://github.com/BotAwesome/example-plugins/blob/main/docs/getting-started.md), [your first Lua plugin](https://github.com/BotAwesome/example-plugins/blob/main/docs/lua-plugins.md#your-first-lua-plugin) and [all documentation](https://github.com/BotAwesome/example-plugins/blob/main/docs/README.md).

## What is in here

```
plugins/<name>/                  plugin sources, one folder each
repo.json, repo.json.sig         the signed index Velouna reads
packages/<id>/<id>-<version>.velounaplugin   built packages
```

`repo.json`, its signature and `packages/` are built from `plugins/`. Never edit them by hand: Velouna checks the signature and refuses a changed index. [What the signature does](https://github.com/BotAwesome/example-plugins/blob/main/docs/repos.md#what-the-signature-does-and-what-it-doesnt).

## License

Each plugin names its license in its `plugin.json`. The Velounizer is GPL-3.0-or-later.
