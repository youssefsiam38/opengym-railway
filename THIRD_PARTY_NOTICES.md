# Third-party notices

## openGym

openGym — Copyright (C) 2026 Duarte Santos — GNU AGPL v3.0 ([licenses/OPENGYM-LICENSE](licenses/OPENGYM-LICENSE)),
with upstream's own notices in [licenses/OPENGYM-NOTICE.md](licenses/OPENGYM-NOTICE.md). The image runs openGym's
official API and web images unmodified; source: https://github.com/DuarteSantos8/openGym. This repository's own
wrapper code is MIT.

## Exercise images and animations

Not part of this repository or the image. With `EXERCISE_MEDIA=download` (the default) each instance downloads them
on first start from https://github.com/hasaneyldrm/exercises-dataset — the same source and mechanism as upstream's
`docker compose` setup. openGym's NOTICE states their ownership is unresolved (Gym visual / ExerciseDB-AscendAPI) and
that they are licensed to neither openGym nor you; they are **not** covered by openGym's AGPL or this repository's MIT
licence. Set `EXERCISE_MEDIA=off` to run without them (the app then shows exercises without pictures).

## Image components

nginx, gettext and curl from Alpine Linux packages; Node.js from the official `node:22-alpine` base used by
openGym's API image.
