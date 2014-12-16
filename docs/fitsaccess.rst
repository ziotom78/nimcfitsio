Basic access to FITS files
==========================

In this section we describe the functions used to access FITS files
and get general information about their content.

All the code from now on can be used only if the NimCfitsio module is
imported with the following command:

.. code-block:: nim

    import cfitsio

Virtually every function in NimCfitsio requires as its first argument
a variable of type :nim:object:`FitsFile`.

.. nim:object:: FitsFile = object

  This object contains the following fields:

============= ================================= =============================
Name          Type                              Meaning
============= ================================= =============================
``file``      ``InternalFitsStruct`` (private)  Used internally by CFITSIO
``fileName``  ``string``                        Name of the file
============= ================================= =============================

In case of error, all the NimCfitsio functions raise an exception of
type :nim:object:`EFitsException`:

.. nim:object:: EFitsException = object

  The fields of this object are the following:

==================== =============== ================================================
Field name           Type            Meaning
==================== =============== ================================================
``code``             ``int``         CFITSIO error code identifier
``message``          ``string``      Descriptive error message
``errorStack``       ``seq[string]`` List of all the CFITSIO error messages raised
==================== =============== ================================================


Opening FITS files for read/write
---------------------------------

The CFITSIO library provides several functions to open a file for
reading/writing, and NimCfitsio provides a wrapper to each of them.
Here is a general overview of their purpose:

====================== ============================================================
Function               Purpose
====================== ============================================================
:nim:proc:`openFile`   Open a generic file. Access through FTP and HTTP is allowed
:nim:proc:`openData`   Open a file and move to the first HDU containing some data
:nim:proc:`openTable`  Like ``openData``, but the HDU must contain a table
:nim:proc:`openImage`  Like ``openData``, but the HDU must contain an image
====================== ============================================================

All the prototypes of these functions accept the same parameters and
return the same result. Here is a short example that shows how to use
them:

.. code-block:: nim

    import cfitsio

    var f = cfitsio.openFile("test.fits", ReadOnly)
    try:
        # Read data from "f"
    finally:
        cfitsio.closeFile(f)

If the underlying CFITSIO function fails when opening the file (e.g,
because the file does not exist), a :nim:object:`EFitsException` will
be raised.

.. nim:enum:: IoMode = enum ReadOnly, ReadWrite

  This enumeration is used by all the procedures that open an existing
  FITS file.

.. nim:proc:: proc openFile(fileName : string, ioMode : IoMode): FitsFile

  Open the FITS file whose path is *fileName*. If *ioMode* is
  ``ReadOnly``, the file is opened in read-only mode and any
  modification is forbidden; if *ioMode* is ``ReadWrite``, then write
  operations are allowed as well as read operations.

  If the file cannot be opened, a :nim:object:`EFitsException` is raised.

  If the underlying CFITSIO library supports them, protocols like
  ``ftp://`` or ``http://`` can be used for *fileName*. Compressed
  files (e.g. ``.gz``) may be supported as well.

  You must call :nim:proc:`closeFile` once the file is no longer
  needed, in order to close the file and flush any pending write
  operation.

.. nim:proc:: proc openData(fileName : string, ioMode : IoMode): FitsFile

  This function can be used instead of :nim:proc:`openData` when the
  user wants to move to the first HDU containing either an image or a
  table. Its usage is the same as :nim:proc:`openFile`.

.. nim:proc:: proc openTable(fileName : string, ioMode : IoMode): FitsFile

  This function is equivalent to :nim:proc:`openData`, but it moves to
  the first HDU containing either a binary or ASCII table.

  If the file cannot be opened, or it does not contain any table, a
  :nim:object:`EFitsException` is raised.

.. nim:proc:: proc openImage(fileName : string, ioMode : IoMode): FitsFile

  This function is equivalent to :nim:proc:`openData`, but it moves to
  the first HDU containing an image.

  If the file cannot be opened, or it does not contain any image, a
  :nim:object:`EFitsException` is raised.

Creating files
--------------

.. nim:enum:: OverwriteMode = enum Overwrite, DoNotOverwrite

.. nim:proc:: proc createFile(fileName : string, overwriteMode : OverwriteMode = Overwrite) : FitsFile

  Create a new file at the path specified by *fileName*. If a file
  already exists, the behavior of the function is specified by the
  *overwriteMode* parameter: if it is equal to ``DoNotOverwrite``, a
  :nim:object:`EFitsException` exception is raised, otherwise the file
  is silently overwritten.

  The return value is a :nim:object:`FitsFile` object that should be
  closed using either :nim:proc:`closeFile` or :nim:proc:`deleteFile`.

  Here is an example about how to use this procedure:

.. code-block:: nim

    import cfitsio

    var f = cfitsio.createFile("test.fits")
    try:
        # Write data into "f"
    finally:
        cfitsio.closeFile(f)


.. nim:proc:: proc createDiskFile*(fileName : string, overwriteMode : OverwriteMode = Overwrite) : FitsFile

  This function is equivalent to :nim:proc::`createFile`, but it does
  not attempt to interpret *fileName* according to CFITSIO's extended
  syntax rules.

Closing files
-------------

.. nim:proc:: proc closeFile(fileObj : var FitsFile)

  Close the file and flush any pending write operation on it. The
  variable *fileObj* can no longer be used after a call to
  ``closeFile``.

  See also :nim:proc:`deleteFile`.

.. nim:proc:: proc deleteFile(fileObj : var FitsFile)

  This procedure is similar to :nim:proc:`closeFile`, but the file is
  deleted after having been closed. It is mainly useful for testing
  purposes.

Other file-related functions
----------------------------

In this section we list all the other functions that work on the file
as a whole, but do not fit in any of the previous sections.

.. nim:proc:: proc getFileName(fileObj : var FitsFile) : string

  Return the name of the file associated with the FITS file variable
  *fileObj*. Since this variable calls CFITSIO instead of simply
  returning the *file* field of :nim:object:`FitsFile`, it could fail.
  In the latter case, it will throw a :nim:object:`EFitsException`
  exception.

.. nim:proc:: proc getFileMode(fileObj : var FitsFile) : IoMode

  Return the I/O mode of the file.

.. nim:proc:: proc getUrlType(fileObj : var FitsFile) : string

  Return the kind of URL of the file. Possible values are e.g.
  ``file://``, ``ftp://``, ``http://``.
