# River of CPAN

The [River of CPAN](https://www.neilb.org/2015/04/20/river-of-cpan.html) assigns
each CPAN distribution a position based on how many other distributions depend on
it, both directly and transitively.

This repository generates a nightly JSON snapshot of river data for every
distribution on CPAN which has a status of "latest" and publishes it to GitHub
Pages.

The nightly JSON will be used by MetaCPAN to provide river position numbers on
dist and module pages. If you think those numbers are incorrect, this is the
place to supply a fix.

## Download

- [river.json](https://metacpan.github.io/metacpan-river/river.json)
- [river.json.gz](https://metacpan.github.io/metacpan-river/river.json.gz)

The JSON is keyed by distribution name:

```json
{
  "Moose": {
    "immediate": 123,
    "total": 5678,
    "bucket": 4
  }
}
```

### Fields

- **immediate** — number of distributions that directly depend on this one
- **total** — number of distributions that depend on it directly or transitively
- **bucket** — river position (0–5) based on log10 of total:
  - 0: total = 0
  - 1: total 1–9
  - 2: total 10–99
  - 3: total 100–999
  - 4: total 1000–9999
  - 5: total 10000+

## Credits

The original River of CPAN was created by
[Neil Bowers](https://metacpan.org/author/NEILB). This version is a
reimplementation for MetaCPAN.
