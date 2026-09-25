# [hickory-dns.org][https://hickory-dns.org/]

Source for the [Hickory DNS](https://github.com/hickory-dns/hickory-dns) website, built with [Zola](https://www.getzola.org/).

```sh
zola serve   # preview at http://127.0.0.1:1111
zola build   # output in public/
```

The front page copy lives in the front matter of `content/_index.md`; markup is in `templates/`, styles in `static/style.css`.
The logo images in `static/` are derived from `logo.png` in the hickory-dns repository (cropped, with a light wordmark variant for dark mode).
