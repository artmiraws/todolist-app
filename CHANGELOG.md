# Changelog

## [1.6.0](https://github.com/artmiraws/todolist-app/compare/v1.5.1...v1.6.0) (2026-09-23)


### Features

* **UI:** change main collor to purple ([c9a04eb](https://github.com/artmiraws/todolist-app/commit/c9a04eb3d85ac73c627a4e596abab32638b0c42c))

## [1.5.1](https://github.com/artmiraws/todolist-app/compare/v1.5.0...v1.5.1) (2026-09-21)


### Bug Fixes

* **chart:** stop a stuck cleanup job from blocking future runs ([5296310](https://github.com/artmiraws/todolist-app/commit/5296310f9bd91650c6c10f7d11ca15b5d973fa48))

## [1.5.0](https://github.com/artmiraws/todolist-app/compare/v1.4.0...v1.5.0) (2026-09-20)


### Features

* **app:** add an ApplicationSet generating one Application per environment ([9499c64](https://github.com/artmiraws/todolist-app/commit/9499c64efda0280c67c3f73f9f3abe8bbc2e98de))

## [1.4.0](https://github.com/artmiraws/todolist-app/compare/v1.3.0...v1.4.0) (2026-09-20)


### Features

* **app:** add a /version endpoint reporting the running version and image ([fb50105](https://github.com/artmiraws/todolist-app/commit/fb501051c542df9affb690970b287c3bd4464a0b))

## [1.3.0](https://github.com/artmiraws/todolist-app/compare/v1.2.0...v1.3.0) (2026-09-20)


### Features

* **app:** drive deploys from GitOps (digest in Git, Argo CD reconciles) ([345caac](https://github.com/artmiraws/todolist-app/commit/345caacc6d07f4965a1d0faa6c04d2fffa4e01a7))


### Bug Fixes

* **app:** target the Argo CD Application name (todolist) in the pipelines ([aa045c7](https://github.com/artmiraws/todolist-app/commit/aa045c7dbb28baba4a33e60161c4a569ce638dcc))

## [1.2.0](https://github.com/artmiraws/todolist-app/compare/v1.1.0...v1.2.0) (2026-09-20)


### Features

* **ci:** read deploy wiring from SSM instead of repo variables ([69b03a2](https://github.com/artmiraws/todolist-app/commit/69b03a219d0b6a4e1e4cabbd14b62e8720a0f83a))

## [1.1.0](https://github.com/artmiraws/todolist-app/compare/v1.0.0...v1.1.0) (2026-09-20)


### Features

* **chart:** add Helm chart for AWS dev ([cee037c](https://github.com/artmiraws/todolist-app/commit/cee037ce8d4e522f4c7320f694e4a73554e4f13a))
* **ci:** add GitHub Actions deploy-dev workflow ([0081096](https://github.com/artmiraws/todolist-app/commit/00810963013892536107526d318ff5df535d63fe))
* **ci:** automate releases from Conventional Commits with release-please ([021fc36](https://github.com/artmiraws/todolist-app/commit/021fc369dc2c449e3ff9d63d604635f737a93c4d))
* **container:** add multi-stage Dockerfile and build exclusions ([73b57c5](https://github.com/artmiraws/todolist-app/commit/73b57c526a5d92b4504678564469f9638407ab46))
* **local-k8s:** add local deployment manifests ([a51150b](https://github.com/artmiraws/todolist-app/commit/a51150b41b0652580d610cb03f5f59b35dd95220))


### Bug Fixes

* **ci:** read variables from the dev GitHub Environment ([da4d880](https://github.com/artmiraws/todolist-app/commit/da4d880456ac318f741cd88e32ea3e53d0da91e1))
* **deps:** support Python 3.14 with psycopg2-binary ([d5837d6](https://github.com/artmiraws/todolist-app/commit/d5837d6205954ab9653dff3295f81a750a0e9822))
