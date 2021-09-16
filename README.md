# lite-lovr
![screenshot](https://user-images.githubusercontent.com/3920290/81471642-6c165880-91ea-11ea-8cd1-fae7ae8f0bc4.png)

A lightweight text editor written in Lua and hosted on LÖVR platform

* **[Original editor code](https://github.com/rxi/lite)**
* **[LÖVR framework](https://github.com/bjornbytes/lovr)**
* **[Plugins](https://github.com/rxi/lite-plugins)**
* **[Color themes](https://github.com/rxi/lite-colors)**

## Overview
lite is a lightweight text editor written in Lua — it aims to provide
something practical, pretty, *small* and fast, implemented as simply as
possible; easy to modify and extend, or to use without doing either.

Original lite runs on top C environment with SDL2 backend. This fork
ports Lua part of lite to run in LÖVR platform, which is cross-platform
framework for 3D and VR games and applications.

## Customization
Additional functionality can be added through plugins which are available from
the [plugins repository](https://github.com/rxi/lite-plugins); additional color
themes can be found in the [colors repository](https://github.com/rxi/lite-colors).
The editor can be customized by making changes to the
[user module](data/user/init.lua).

## Running
No compiling is needed. LÖVR runtime can run the lite-lovr just by passing the
correct directory to lovr executeable.

## Contributing
The original author considers lite to be feature-complete and does not accept
changes to editor. This fork makes minimal changes in lite code, as needed to
run in lovr. I hope the fork won't make any substantial departure from lite.

Any bug reports, fixes and features that enhance the editor intergration with
lovr are very wecome.

## License
This project is free software; you can redistribute it and/or modify it under
the terms of the MIT license. See [LICENSE](LICENSE) for details.
