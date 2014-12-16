HDU functions
=============

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
