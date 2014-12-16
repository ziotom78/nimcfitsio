Basic access to FITS files
==========================

In this section we describe the functions used to access FITS files
and get general information about their content.

All the code from now on can be used only if the NimCfitsio module is
imported with the following command:

.. code-block:: nim

    import cfitsio

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

.. nim:proc:: proc createFile*(fileName : string, overwriteMode : OverwriteMode = Overwrite) : FitsFile

.. nim:proc:: proc createDiskFile*(fileName : string, overwriteMode : OverwriteMode = Overwrite) : FitsFile


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

.. nim:proc:: proc getFileMode(fileObj : var FitsFile) : IoMode

.. nim:proc:: proc getUrlType(fileObj : var FitsFile) : string


Moving through the HDUs
-----------------------

A FITS files is composed by one or more HDUs. NimCfitsio provides a
number of functions to know how many HDUs are present in a FITS file
and what is their content. (To create a new HDU you have first to
decide which kind of HDU you want. Depending on the answer, you should
read :ref:`table-functions` or :ref:`image-functions`.)

.. nim:enum:: HduType = enum Any = -1, Image = 0, AsciiTable = 1, BinaryTable = 2

  HDU types recognized by NimCfitsio. The ``Any`` type is used by
  functions which perform searches on the available HDUs in a file.
  See the FITS specification documents for further information about
  the other types.

NimCfitsio (and CFITSIO itself) uses the concept of "current HDU".
Each :nim:object:`FitsFile` variable is a stateful object. Instead of
specifying on which HDU a NimCfitsio procedure should operate, the
user must first select the HDU and then call the desired procedure.

.. nim:proc:: proc moveToAbsHdu(fileObj : var FitsFile, num : int) : HduType

  Select the HDU at position *idx* as the HDU to be used for any
  following operation on the FITS file. The value of *num* must be
  between 1 and the value returned by :nim:proc:`getNumberOfHdus`.

.. nim:proc:: proc moveToRelHdu(fileObj : var FitsFile, num : int) : HduType

  Move the current HDU by *num* positions. If *num* is 0, this is a
  no-op. Positive as well as negative values are allowed.

.. nim:proc:: proc moveToNamedHdu(fileObj : var FitsFile, hduType : HduType, name : string, ver : int = 0)

  Move to the HDU whose name is *name*. If *ver* is not zero, then the
  HDU must match the version number as well as the name.

  If no matching HDU are found, a :nim:object:`EFitsException` is raised.

.. nim:proc:: proc getNumberOfHdus(fileObj : var FitsFile) : int

  Return the number of HDUs in the FITS file.
