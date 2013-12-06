---
layout: post
title: Garbage Collector
summary: Enabled the Boehm GC
thumbnail: gc
author: waj
---

Finally Crystal will start giving some memory back to the operating system! Today we managed to fit the [Boehm-Demers-Weiser conservative garbage collector](http://www.hpl.hp.com/personal/Hans_Boehm/gc/) into the language.

Although we plan to implement a more appropiate and custom garbage collector in the future, it's a really good starting point to make the language more robust and usable.

In order to make this collector work with Crystal we had to make sure all the allocated block pointers were properly [aligned in memory](https://github.com/manastech/crystal/commit/6657d3c84c93ec0c886aa9262b2a33791e22285f). Unions and type hierarchies were using packed structs and that made some pointers "invisible" to the GC and thus many blocks still in use were being deallocated and consecuently making everything crash quite easily.

Some quick tests reflect the obvious benefits of freeing some memory. For example, `samples/mandelbrot2.cr` used to require around 13MB of memory to run. Once the GC is enabled it uses just under 1MB.

There is still a long path to travel, but now with a working memory manager we might consider start [dogfooding](http://en.wikipedia.org/wiki/Eating_your_own_dog_food) Crystal for some non production or critical tools in our everyday work.
