Introduction
============

This manual describes NimCfitsio, a set of bindings to the `CFITSIO
<http://heasarc.gsfc.nasa.gov/fitsio/fitsio.html>`_ library for the
Nim language.

The purpose of NimCfitsio is to allow the creation/reading/writing of
FITS files (either containing images or tables) from Nim programs. The
interface matches the underlying C library quite close, but in a
number of cases the syntax is nicer, thanks to Nim's richer and more
expressive syntax.

So far the library provides an extensive, albeit not complete,
coverage of the functions to read/write keywords and ASCII/binary
tables. More extensive support for reading/writing images (i.e., 2D
matrices of numbers) is yet to come.
