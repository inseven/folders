# Folders (Rust)

Proof-of-concept reimplementation of Fileaway in Rust

## Details

Since spending more time using Fedora and GNOME, I've found myself missing [Fileaway](https://github.com/inseven/fileaway) and [Folders](https://github.com/inseven/folders), my file management apps for macOS and iOS. This repository is therefore an experiment to see how hard it would be to reimplement the file observing core of those apps in Rust to be shared across both Apple-native and Linux-native UI toolkits. It's very much a learning exercise and you probably don't want to use this code for... anything in its current form. Not least because it's the first time I'm writing Rust and GTK. If it evolves into something more funcitonal, I'll likely turn it into a dedicated library, or fold it into Fileaway or Rust.
