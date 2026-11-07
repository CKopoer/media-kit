# Pinned SDK dependency notices

These unmodified notices supplement those collected from the build container.
The SDK is built with mpv `-Dgpl=false` and FFmpeg's LGPL variant (version 3).
This does not replace the individual dependencies' copyright and license terms.

- [LuaJIT](https://github.com/LuaJIT/LuaJIT/tree/ea9eb7edb5eac4a9d175d74523db34fac0fa5180): MIT, original `COPYRIGHT`.
- [libsixel](https://github.com/libsixel/libsixel/tree/3c9fd6a294b2d0338482f9a5d5772827d82cfa9d): MIT and the original component `LICENSE*` notices.
- [subrandr](https://github.com/afishhh/subrandr/tree/a41311bb5e382abcc47ef141e2ea1098d22a8d58): MPL-2.0, original `LICENSE`; corresponding source is available at this exact commit.

`provenance/repack.json` records the input CI archive digest and verifies that
adding these notices did not change DLLs, import libraries, headers or JARs.
The packaging script and notice files are maintained with the media-kit fork.
Source commits, FFmpeg configuration, Meson options/dependencies and the pinned
BtbN build-container digest are recorded beside this directory in the SDK.
