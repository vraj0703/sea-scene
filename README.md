# sea-scene

**Live: https://vishalraj-sea-scene.web.app**

A beach at dusk that answers the weather. The curtain opens on a sea drawn
entirely by a fragment shader; a mark, a name and four cards arrive in turn,
each on its own note; and pressing a card puts lightning in the sky and
scatters the birds.

Part of a set of three, each independent and each on its own Firebase project:

| | |
|---|---|
| Portfolio | https://vishalraj.space |
| Space scene | https://vishalraj-space-scene.web.app |
| Sea scene | https://vishalraj-sea-scene.web.app |

It is a port of the contact section from the previous site, which ran inside a
much larger Flame game. Everything here is the same scene rebuilt on the
portfolio's architecture, so the two can be read side by side.

## Running it

```bash
flutter run -d chrome
```

## What the scene is made of

**The sea is one shader.** [`assets/shaders/beach.frag`](assets/shaders/beach.frag)
draws the water, the sky, the sun and the reflections, driven by eighteen
uniforms set from
[`lib/presentation/beach/beach_background.dart`](lib/presentation/beach/beach_background.dart).
Two of those uniforms are worth knowing about:

- **`uWaterY` is in pixels, not a fraction.** The shader divides a fragment's
  own `y` by it, so handed a fraction it reads every pixel as infinitely deep,
  clamps, and reflects nothing at all — the sea looks right and mirrors
  nothing.
- **The water only mirrors what is above the waterline.** That is why the cards
  stand where they do; it is not a composition choice, it decides whether they
  have a reflection at all. There is a test for it.

**The cards are photographed, not re-rendered.** A `RepaintBoundary` around
them is read back every 500ms at half resolution and handed to the shader as
the thing the water reflects. Both numbers are load-bearing: water is blurry
and slow, so a reflection that lags is indistinguishable from one that does
not, and the shader tears the image apart before anyone sees it.

**The hallway has real depth.** The four cards are translated in z under a
perspective matrix rather than merely scaled, so the inner pair foreshorten.
The hit region sits *outside* that transform — a perspective `Transform` is
non-affine and breaks Flutter's hit-testing, so a `MouseRegion` inside one
never fires.

**The arrival is a scale.** Six things land in order — the mark, the name, then
the four cards — each with its own note. Four cards landing together would play
as a chord, and a chord says nothing about sequence.

## How it is arranged

The same three layers as the portfolio.

- `domain/` — the numbers and the pure logic over them (`BeachConfig`,
  `EntrySequence`, the weather classes). No Flutter where it can be helped;
  this is the part the tests are about.
- `data/` — the container, the audio backend and the shader library.
- `presentation/` — `SceneBloc` (loading, then ready, then the beach) and the
  widgets and Flame components that draw.

Type and colour come from `domain/style/`, using the portfolio's own faces so
the three sites read as one hand.

## Tests

```bash
flutter test
```

They cover the parts that fail silently: that every audio cue names a file
that is actually in `assets/audio` (one absent file used to abort the whole
cache warm-up and silence the scene), that the cards stand above the waterline,
and that the storm's timings behave like weather rather than like a strobe.

## Publishing

A push to `master` runs analyse, test, build and deploy — see
[`.github/workflows/deploy.yml`](.github/workflows/deploy.yml). The deploy step
shares a job with the tests, so a red test ends the run before it can ship.

Its Firebase project is `vishalraj-sea-scene`, deliberately separate from the
portfolio's and the space scene's: Firebase Hosting replaces a site's entire
contents on every deploy, so two things sharing one site would each wipe the
other.
