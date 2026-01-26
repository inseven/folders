# Folders

[![build](https://github.com/inseven/folders/actions/workflows/build.yaml/badge.svg)](https://github.com/inseven/folders/actions/workflows/build.yaml)

Offline library management for your files

![](screenshots/macos.png)

## Platforms

### macOS


### Linux

Right now, this is simply a proof-of-concept reimplementation using Rust and GTK.

>  Since spending more time using Fedora and GNOME, I've found myself missing [Fileaway](https://github.com/inseven/fileaway) and [Folders](https://github.com/inseven/folders), my file management apps for macOS and iOS. This repository is therefore an experiment to see how hard it would be to reimplement the file observing core of those apps in Rust to be shared across both Apple-native and Linux-native UI toolkits. It's very much a learning exercise and you probably don't want to use this code for... anything in its current form. Not least because it's the first time I'm writing Rust and GTK. If it evolves into something more functional, I'll likely turn it into a dedicated library, or fold it into Fileaway or Rust.

## Development

### Dependencies

Folders uses [mise-en-place](https://mise.jdx.dev) and the `.tool-versions` file to manage development tools dependencies. After [installing mise](https://mise.jdx.dev/installing-mise.html), you can install the necessary tooling as follows:

```shell
mise install
```

Some of the build script configure a local directory of dependencies in `.local`. You can install these in preparation for running full builds as follows:

```shell
scripts/install-dependencies.sh
```

### Documentation

The [project website](https://folders.jbmorley.co.uk) is built using a combination of Jekyll and a couple of custom bash scripts to build-out the release pages.

You can run a local Jekyll server for development as follows (see [Dependencies](#dependencies) for details on how to install the necessary tools dependencies):

```shell
cd docs
bundle exec jekyll serve --watch
```

## License

Folders is licensed under the MIT License (see [LICENSE](LICENSE)). It depends on the following separately licensed third-party libraries and components:

- [Diligence](https://github.com/inseven/diligence), MIT License
- [FSEventsWrapper](https://github.com/Frizlab/FSEventsWrapper), MIT License
- [Interact](https://github.com/inseven/interact), MIT License
- [Licensable](https://github.com/inseven/licensable), MIT License
- [Sparkle](https://github.com/sparkle-project/Sparkle), Sparkle License
- [SQLite.swift](https://github.com/stephencelis/SQLite.swift), MIT License
- [Swift Algorithms](https://github.com/apple/swift-algorithms), Apache 2.0 License
- [Swift Collections](https://github.com/apple/swift-collections), Apache 2.0 License
- [Swift Numerics](https://github.com/apple/swift-numerics), Apache 2.0 License
- [Yams](https://github.com/jpsim/Yams), MIT License
