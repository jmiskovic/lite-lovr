# lite-lovr
![screenshot](https://user-images.githubusercontent.com/17770782/133811107-6859c842-939f-474b-90a2-c9e3ec6cdd4a.png)


A lightweight text editor written in Lua and hosted on LÖVR platform

* **[Original editor code](https://github.com/rxi/lite)**
* **[LÖVR framework](https://github.com/bjornbytes/lovr)**
* **[Plugins](https://github.com/rxi/lite-plugins)**
* **[Color themes](https://github.com/rxi/lite-colors)**

## Overview
lite is a lightweight text editor written in Lua — it aims to provide something practical, pretty, *small* and fast, implemented as simply as possible; easy to modify and extend, or to use without doing either.

Original lite runs on top C environment with SDL2 backend. This fork ports Lua part of lite to run in LÖVR platform, which is cross-platform
framework for 3D and VR games and applications.

## Customization
Additional functionality can be added through plugins which are available from the [plugins repository](https://github.com/rxi/lite-plugins); additional color themes can be found in the [colors repository](https://github.com/rxi/lite-colors).
The editor can be customized by making changes to the [user module](data/user/init.lua).

## Running

```sh
cd src
lovr .
```

## TODOs

* the reading and writing happens through io.open() instead lovr.filesystem.read/write
* mouse interactions through VR controller or head orientation (raytrace, draw cursor, inject events)
* window resizing
* lite enforces 'strict' Lua usage for everyone
* lite requires global variables: ARGS, SCALE, EXEDIR, PATHSEP, renderer, system
* because of z-fighting, lite has depth test disabled and thus has to render last
* implement the rect clipping with stencils (or render to canvas)

## Contributing
The original author considers lite to be feature-complete and does not merge any functional changes to the editor. This fork tries to minimize changes to the lite code, as required to run on LÖVR.

Any bug reports, fixes and features that enhance the editor intergration with lovr are very welcome.

## License
This project is free software; you can redistribute it and/or modify it under the terms of the MIT license. See [LICENSE](LICENSE) for details.
