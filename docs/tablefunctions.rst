.. _table-functions:

Table functions
===============

Creating tables
---------------

.. nim:enum:: TableType = enum AsciiTable, BinaryTable

  This enumeration lists the two types of tables that can be found in
  a FITS file. Binary tables have the advantage of allowing any
  datatype supported by CFITSIO; moreover, they are more efficient in
  terms of required storage.

.. nim:enum:: DataType = enum dtBit, dtInt8, dtUint8, dtInt16, dtUint16, dtInt32, dtInt64, dtFloat32, dtFloat64, dtComplex32, dtComplex64, dtLogical, dtString

  Data types recognized by NimCfitsio.

.. nim:object:: TableColumn = object

  This type describes one column in a table HDU. It is used by
  :nim:proc:`createTable`. Its fields are listed in the following
  table:

================ ===================== ===================================================
Field            Type                  Description
================ ===================== ===================================================
``name``         ``string``            Name of the column (not longer than 8 chars)
``dataType``     :nim:enum:`DataType`  Data type
``width``        ``int``               For strings, this gives the maximum number of chars
``repeatCount``  ``int``               Number of items per row
``unit``         ``string``            Measure unit
================ ===================== ===================================================


.. nim:proc:: proc createTable(fileObj : var FitsFile, tableType : TableType, numOfElements : int64, fields : openArray[TableColumn], extname : string)

  Create a new table HDU after the current HDU. The file must have
  been opened in ``ReadWrite`` mode (this is automatically the case if
  *f* has been returned by a call to :nim:proc:`createFile`).

  The value of *numOfElements* is used to allocate some space, but it
  can be set to zero: calls to functions like :nim:proc:`writeColumn`
  will make room if needed.

Reading columns
---------------

The NimCfitsio library provides an extensive set of functions to read
data from FITS table HDUs. Each of them initializes an "open array"
type that is passed as a ``var`` argument: this allows to initialize
arrays as well as ``seq`` types.

The functions implemented by NimCfitsio to read columns of data are
the following:

==================================== ===========
Function name                        Type
==================================== ===========
:nim:proc:`readColumnOfInt8`         ``int8``
:nim:proc:`readColumnOfInt16`        ``int16``
:nim:proc:`readColumnOfInt32`        ``int32``
:nim:proc:`readColumnOfInt64`        ``int64``
:nim:proc:`readColumnOfFloat32`      ``float32``
:nim:proc:`readColumnOfFloat64`      ``float64``
:nim:proc:`readColumnOfString`       ``string``
==================================== ===========

We describe here the many incarnations of a function
:nim:proc:`readColumn` which operates on a generic type ``T``. Such
function however does not exist: such description should be applied to
any of the procedures listed in the table above.

.. nim:proc:: proc readColumn(fileObj : var FitsFile, colNum : int, firstRow : int, firstElem : int, numOfElements : int, dest : var openArray[T], destNull : var openArray[bool], destFirstIdx : int)

  Read a number of elements equal to *numOfElements* from the column
  at position *colNum* (the position of the first column is 1),
  starting from the row number *firstRow* (starting from 1) and the
  element *firstElem* (within the row; this also starts from 1). The
  destination is saved in the *dest* array, starting from the index
  *destFirstIdx*. The array *destNull* must be defined on the same
  indexes as the array *dest*; :nim:proc:`readColumn` initializes it
  with either *true* or *false*, according to the nullity of the
  corresponding element in *dest*.

  As an example, the following call reads 3 elements from the first
  column of file *f*. The values read from the file are saved in
  ``dest[2]``, ``dest[3]``, and ``dest[4]``, because *destFirstIdx*
  is 2. Note that *nullFlag* is not as long as *dest* (4 elements
  instead of 10): this is ok, as the upper limit of the indexes used
  by the procedure is 4.

.. code-block:: nim

   var dest : array[int32, 10]
   var nullFlag : array[int32, 4]
   f.readColumnOfInt32(1, 4, 1, 3, dest, destNull, 2)

.. nim:proc:: proc readColumn(fileObj : var FitsFile, colNum : int, firstRow : int, firstElem : int, numOfElements : int, dest : var openArray[T], destFirstIdx : int, nullValue : T)

  This second version of the procedure allows for quickly substitute
  null values with the value *nullValue*.

.. nim:proc:: proc readColumn(fileObj : var FitsFile, colNum : int, firstRow : int, firstElem : int, dest : var openArray[T], nullValue : T)

  In many cases it is not needed to save data in the middle of the
  *dest* array. This version of ``readColumn`` uses the length of
  *dest* as the value to be used for *numOfElements*. The implicit
  value of *firstElem* is ``low(dest)``.

.. nim:proc:: proc readColumn(fileObj : var FitsFile, colNum : int, dest : var openArray[T], nullValue : T)

  This is the simplest possible version of ``readColumn``. It reads
  as many values as they fit in *dest*, starting from the first one
  (i.e., *firstRow* and *firstElem* are implicitly set to 1).


Writing columns
---------------

The functions implemented by NimCfitsio to write columns of data are
the following:

==================================== ===========
Function name                        Type
==================================== ===========
:nim:proc:`writeColumnOfInt8`        ``int8``
:nim:proc:`writeColumnOfInt16`       ``int16``
:nim:proc:`writeColumnOfInt32`       ``int32``
:nim:proc:`writeColumnOfInt64`       ``int64``
:nim:proc:`writeColumnOfFloat32`     ``float32``
:nim:proc:`writeColumnOfFloat64`     ``float64``
:nim:proc:`writeColumnOfString`      ``string``
==================================== ===========

.. nim:proc:: proc writeColumn(fileObj : var FitsFile, colNum : int, firstRow : int, firstElem : int, numOfElements : int, values : var openArray[T], valueFirstIdx : int, nullPtr : ptr T = nil)

  Write *numOfElements* values taken from *values* into the column at
  position *colNum* in the current HDU of the FITS file *f*. The
  elements will be written starting from the row with number
  *firstRow* (the first row is 1) and from the element in the row at
  position *firstElem* (the first element is 1). The values that are
  saved in the file start from the index *valueFirstIdx*, i.e., they
  are ``values[valueFirstIdx]``, ``values[valueFirstIdx+1]`` and so
  on.

  The *nullPtr* argument is a **pointer** to a variable that contains
  the "null" value: any value in *values* that is going to be written
  is compared with ``nullPtr[]`` and, if it is equal, it is set to
  NULL.

.. nim:proc:: proc writeColumn(fileObj : var FitsFile, colNum : int, firstRow : int, firstElem : int, values : var openArray[T], nullPtr : ptr T = nil)

  This is a wrapper around the previous definition of
  :nim:proc:`writeColumn`. It assumes that ``valueFirstIdx =
  low(values)``.

.. nim:proc:: proc writeColumn(fileObj : var FitsFile, colNum : int, values : var openArray[T], nullPtr : ptr T = nil)

  This function is a wrapper around the previous definition of
  :nim:proc:`writeColumn`. It writes all the elements of the *values*
  array into the column *colNum*.
