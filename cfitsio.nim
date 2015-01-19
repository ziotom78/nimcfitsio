# -*- nimrod -*-
#
# cfitsio.nim
#
# Maurizio Tomasi
# Created on 5 Dic 2014
#
# Bindings to the CFITSIO library

import strutils

when defined(windows):
    const LibraryName = "cfitsio.dll"
elif defined(macosx):
    const LibraryName = "libcfitsio(|.0).dylib"
else:
    const LibraryName = "libcfitsio.so"

const
    flenFileName* = 1025 ## Maximum length (in characters) of the name of a file
    flenKeyword* = 72 ## Maximum length (in characters) of a keyword (including the comments)
    flenCard* = 81 ## Maximum length (in characters) of a keyword card
    flenValue* = 71 ## Maximum length (in characters) of a keyword value
    flenComment* = 73 ## Maximum length (in characters) of a keyword comment
    flenErrMsg* = 81 ## Maximum length (in characters) of an error message
    flenStatus* = 31 ## Maximum length (in characters) of a short error message ("status message")

    tBit* = 1 ## Bit datatype
    tByte* = 11 ## Byte (8-bit unsigned integer) datatype
    tLogical* = 14 ## Logical (Boolean) datatype
    tString* = 16 ## String datatype
    tShort* = 21 ## Short (16-bit signed integer) datatype
    tLong* = 41 ## Long (32-bit or 64-bit signed integer) datatype
    tLongLong* = 81 ## Long-long (64-bit signed integer) datatype
    tFloat* = 42 ## Float (32-bit floating-point number) datatype
    tDouble* = 82 ## Double (64-bit floating-point number) datatype
    tComplex* = 83 ## Complex (2 x 32-bit complex floating-point number) datatype
    tDblComplex* = 163 ## Double complex (2 x 64-bit complex floating-point number) datatype
    tInt* = 31 ## Integer datatype (its size matches the size of a pointer)
    tSbyte* = 12 ## Signed byte (8-bit signed integer) datatype
    tUint* = 30 ## Unsigned int (its size matches the size of a pointer)
    tUshort* = 20 ## Unsigned short (16-bit integer) datatype
    tUlong* = 40 ## Unsigned long (32-bit integer) datatype
    tInt32bit* = 41 ## Shortcut for tLong

type
    DataType = enum
        dtBit,
        dtInt8, dtUint8, dtInt16, dtUint16, dtInt32, dtInt64,
        dtFloat32, dtFloat64,
        dtComplex32, dtComplex64,
        dtLogical,
        dtString

    InternalFitsStruct = pointer ## Used internally by these bindings

    EFitsException* = object of Exception
        ## Generic exception
        code : int ## CFITSIO status code
        errorStack : seq[string] ## List of error messages associated with the error

    IoMode* = enum  ## Possible ways to open a FITS file
        ReadOnly = 0, ReadWrite = 1

    HduType* = enum ## Recognized types of HDUs in a FITS file
        Any = -1, Image = 0, AsciiTable = 1, BinaryTable = 2

    FileNameStr* = array[0..flenFileName, char]
    KeywordStr* = array[0..flenKeyword, char]
    CardStr* = array[0..flenCard, char]
    ValueStr* = array[0..flenValue, char]
    CommentStr* = array[0..flenComment, char]
    ErrMsgStr* = array[0..flenErrMsg, char]

    FitsFile* {. final .} = object
        ## Connection to an opened FITS file
        file : InternalFitsStruct
        fileName : string

    Complex32 = object
        re : float32
        im : float32

    Complex64 = object
        re : float64
        im : float64

#-------------------------------------------------------------------------------

proc fitsGetErrStatus(statusCode : int,
                      errorText : ErrMsgStr) {. cdecl,
                                                dynlib : LibraryName,
                                                importc : "ffgerr" .}

proc fitsReadErrMsg(errorText : ErrMsgStr) : int {. cdecl,
                                                    dynlib : LibraryName,
                                                    importc : "ffgmsg" .}

proc raiseFitsException(statusCode : int, spec : string) {. noinline, noreturn .} =
    var errorText : ErrMsgStr
    fitsGetErrStatus(statusCode, errorText)

    var message : string = $errorText
    if spec != "":
        message = message & " (" & spec & ")"

    var exception : ref EFitsException
    new(exception)
    exception.code = statusCode
    exception.msg = message

    # Get the list of error messages from CFITSIO's error stack.
    # Unfortunately, there is no way to know in advance how many
    # messages are in the stack.
    newSeq(exception.errorStack, 0)
    while fitsReadErrMsg(errorText) != 0:
        add(exception.errorStack, $errorText)

    raise exception

proc raiseFitsException(statusCode : int) {. noinline, noreturn .} =
    raiseFitsException(statusCode, "")

#-------------------------------------------------------------------------------

proc dataTypeChar(dataType : DataType) : char {. noSideEffect, inline .} =
    case dataType
    of dtBit: result = 'X'
    of dtInt8: result = 'S'
    of dtUint8: result = 'B'
    of dtInt16: result = 'I'
    of dtUint16: result = 'U'
    of dtInt32: result = 'J'
    of dtInt64: result = 'K'
    of dtFloat32: result = 'E'
    of dtFloat64: result = 'D'
    of dtComplex32: result = 'C'
    of dtComplex64: result = 'M'
    of dtLogical: result = 'L'
    of dtString: result = 'A'

proc codeToDataType(code : int) : DataType {. noSideEffect, inline .} =
    case code
    of tBit: result = dtBit
    of tByte: result = dtUint8
    of tLogical: result = dtLogical
    of tString: result = dtString
    of tShort: result = dtInt16
    of tLong: result = dtInt64
    of tLongLong: result = dtInt64
    of tFloat: result = dtFloat32
    of tDouble: result = dtFloat64
    of tComplex: result = dtComplex32
    of tDblComplex: result = dtComplex64
    of tInt: result = dtInt32
    of tSbyte: result = dtInt8
    of tUint: result = dtInt64
    of tUshort: result = dtUint16
    of tUlong: result = dtInt64
    else:
        raise newException(KeyError, "data type " & $code & " is not recognized by CFITSIO")

#-------------------------------------------------------------------------------

proc fitsOpenFile(filePtr : ptr InternalFitsStruct,
                  fileName : cstring,
                  ioMode : IoMode,
                  status : ptr int): int {. cdecl,
                                            dynlib : LibraryName,
                                            importc : "ffopen" .}

proc openFile*(fileName : string, ioMode : IoMode): FitsFile =
    ## Open an existing FITS file. The parameter `ioMode` specifies if
    ## the file will be opened only for reading (``ReadOnly``) or for
    ## reading and writing (``ReadWrite``). If the file does not
    ## exist, a EFitsException will be raised.

    var status = 0
    result.file = nil
    result.fileName = fileName
    if fitsOpenFile(addr(result.file), fileName, ioMode, addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsOpenData(filePtr : ptr InternalFitsStruct,
                  fileName : cstring,
                  ioMode : IoMode,
                  status : ptr int): int {. cdecl,
                                            dynlib : LibraryName,
                                            importc : "ffdopn" .}

proc openData*(fileName : string, ioMode : IoMode): FitsFile =
    ## This function is similar to `openFile`, but it automatically
    ## moves the current HDU pointer to the first HDU containing data
    ## (either an image or a table).

    var status = 0
    result.file = nil
    result.fileName = fileName
    if fitsOpenData(addr(result.file), fileName, ioMode, addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsOpenTable(filePtr : ptr InternalFitsStruct,
                   fileName : cstring,
                   ioMode : IoMode,
                   status : ptr int): int {. cdecl,
                                             dynlib : LibraryName,
                                             importc : "fftopn" .}

proc openTable*(fileName : string, ioMode : IoMode) : FitsFile =
    ## This function is similar to `openFile`, but it automatically
    ## moves the current HDU pointer to the first HDU containing an
    ## ASCII or binary table. If no HDUs containing tables are found,
    ## a ``EFitsException`` is raised.

    var status = 0
    result.file = nil
    result.fileName = fileName
    if fitsOpenTable(addr(result.file), fileName, ioMode, addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsOpenImage(filePtr : ptr InternalFitsStruct,
                   fileName : cstring,
                   ioMode : IoMode,
                   status : ptr int): int {. cdecl,
                                             dynlib : LibraryName,
                                             importc : "ffiopn" .}

proc openImage*(fileName : string, ioMode : IoMode) : FitsFile =
    ## This function is similar to `openFile`, but it automatically
    ## moves the current HDU pointer to the first HDU containing a 2D
    ## image. If no HDUs containing images are found, a
    ## ``EFitsException`` is raised.

    var status = 0
    result.file = nil
    result.fileName = fileName
    if fitsOpenImage(addr(result.file), fileName, ioMode, addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsCreateFile(filePtr : ptr InternalFitsStruct,
                    fileName : cstring,
                    status : ptr int) : int {. cdecl,
                                               dynlib : LibraryName,
                                               importc : "ffinit" .}

type
    OverwriteMode* = enum
        Overwrite, DoNotOverwrite

proc createFile*(fileName : string,
                 overwriteMode : OverwriteMode = Overwrite) : FitsFile =
    ## Create a new, empty FITS file with name `fileName`. If it is
    ## impossible to create the file, a ``EFitsException`` exception
    ## will be raised. Once the file is created, you should populate
    ## it using the function createTable.

    var status = 0
    result.file = nil
    result.fileName = fileName

    var realName = fileName
    if overwriteMode == Overwrite and realName[0] != '!':
        realName = '!' & realName

    if fitsCreateFile(addr(result.file), realName, addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsCreateDiskFile(filePtr : ptr InternalFitsStruct,
                        fileName : cstring,
                        status : ptr int) : int {. cdecl,
                                                   dynlib : LibraryName,
                                                   importc : "ffdkinit" .}

proc createDiskFile*(fileName : string,
                     overwriteMode : OverwriteMode = Overwrite) : FitsFile =
    ## This function is similar to `createFile`, but it ensures that a
    ## real FITS file is indeed created on disk. (The `createFile`
    ## function parses `fileName` and, depending on its format, might
    ## choose to create a memory file -- see the CFITSIO documentation
    ## about the function ``ffinit`` for more details.)

    var status = 0
    result.file = nil
    result.fileName = fileName

    var realName = fileName
    if overwriteMode == Overwrite and realName[0] != '!':
        realName = '!' & realName

    if fitsCreateDiskFile(addr(result.file), realName, addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsCloseFile(filePtr : InternalFitsStruct,
                   status : ptr int) : int {. cdecl,
                                              dynlib : LibraryName,
                                              importc : "ffclos" .}

proc closeFile*(fileObj : var FitsFile) =
    ## Close a FITS file. If contents have been written or updated, it
    ## is important to call this function: the latest modifications
    ## might not have been written to disk yet. Note that this
    ## function *might fail*, so it is possible that it throws a
    ## ``EFitsException`` exception.

    var status = 0
    if fitsCloseFile(fileObj.file, addr(status)) != 0:
        raiseFitsException(status, "(file: \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsDeleteFile(filePtr : InternalFitsStruct,
                    status : ptr int) : int {. cdecl,
                                               dynlib : LibraryName,
                                               importc : "ffdelt" .}

proc deleteFile*(fileObj : var FitsFile) =
    ## Delete an opened FITS file from the disk.

    var status = 0
    if fitsDeleteFile(fileObj.file, addr(status)) != 0:
        raiseFitsException(status, "(file: \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsFileName(filePtr : InternalFitsStruct,
                  fileName : array[0..flenFileName, char],
                  status : ptr int) : int {. cdecl,
                                             dynlib : LibraryName,
                                             importc : "ffflnm" .}

proc getFileName*(fileObj : var FitsFile) : string =
    ## Return the name of the file associated with the ``FitsFile`` object.

    var status = 0
    var cResult : array[0..flenFileName, char]
    if fitsFileName(fileObj.file, cResult, addr(status)) != 0:
        raiseFitsException(status, "(file: \"" & fileObj.fileName & "\"")
    result = $cResult

#-------------------------------------------------------------------------------

proc fitsFileMode(filePtr : InternalFitsStruct,
                  mode : ptr IoMode,
                  status : ptr int) : int {. cdecl,
                                             dynlib : LibraryName,
                                             importc : "ffflmd" .}

proc getFileMode*(fileObj : var FitsFile) : IoMode =
    var status = 0
    var mode : IoMode
    if fitsFileMode(fileObj.file, addr(mode), addr(status)) != 0:
        raiseFitsException(status, "(file: \"" & fileObj.fileName & "\"")
    result = mode

#-------------------------------------------------------------------------------

proc fitsUrlType(filePtr : InternalFitsStruct,
                 urlType : array[0..flenFileName, char],
                 status : ptr int) : int {. cdecl,
                                            dynlib : LibraryName,
                                            importc : "ffurlt" .}

proc getUrlType*(fileObj : var FitsFile) : string =
    var status = 0
    var cResult : array[0..flenFileName, char]
    if fitsUrlType(fileObj.file, cResult, addr(status)) != 0:
        raiseFitsException(status, "(file: \"" & fileObj.fileName & "\"")
    result = $cResult

#-------------------------------------------------------------------------------

proc fitsMovabsHdu(filePtr : InternalFitsStruct,
                   hduNum : int,
                   hduType : ptr int,
                   status : ptr int) : int {. cdecl,
                                             dynlib : LibraryName,
                                             importc : "ffmahd" .}

proc moveToAbsHdu*(fileObj : var FitsFile, num : int) : HduType =
    var status = 0
    var cHduType = 0
    if fitsMovabsHdu(fileObj.file, num, addr(cHduType), addr(status)) != 0:
        raiseFitsException(status, "HDU number " & $num &
                                   " in file \"" & fileObj.fileName & "\"")
    result = HduType(cHduType)

#-------------------------------------------------------------------------------

proc fitsMovrelHdu(filePtr : InternalFitsStruct,
                   hduNum : int,
                   hduType : ptr int,
                   status : ptr int) : int {. cdecl,
                                              dynlib : LibraryName,
                                              importc : "ffmrhd" .}

proc moveToRelHdu*(fileObj : var FitsFile,
                   num : int) : HduType =
    var status = 0
    var cHduType = 0
    if fitsMovrelHdu(fileObj.file, num, addr(cHduType), addr(status)) != 0:
        raiseFitsException(status, "relative HDU number " & $num &
                                   " in file \"" & fileObj.fileName & "\"")
    result = HduType(cHduType)

#-------------------------------------------------------------------------------

proc fitsMovnamHdu(filePtr : InternalFitsStruct,
                   hduType : int,
                   extName : cstring,
                   extVer : int,
                   status : ptr int) : int {. cdecl,
                                              dynlib : LibraryName,
                                              importc : "ffmnhd" .}

proc moveToNamedHdu*(fileObj : var FitsFile,
                     hduType : HduType,
                     name : string,
                     ver : int = 0) =
    var status = 0
    if fitsMovnamHdu(fileObj.file, int(hduType), name, ver, addr(status)) != 0:
        raiseFitsException(status, "HDU " & name &
                                   " in file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsGetNumHdus(filePtr : InternalFitsStruct,
                    num : ptr int,
                    status : ptr int) : int {. cdecl,
                                              dynlib : LibraryName,
                                              importc : "ffthdu" .}

proc getNumberOfHdus*(fileObj : var FitsFile) : int =
    var status = 0
    var cResult : int = 0
    if fitsGetNumHdus(fileObj.file, addr(cResult), addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileObj.fileName & "\"")

    result = cResult

#-------------------------------------------------------------------------------

proc fitsReadKey(filePtr : InternalFitsStruct,
                 datatype : int,
                 keyname : cstring,
                 value : ptr char,
                 comment : cstring,
                 status : ptr int) : int {. cdecl,
                                            dynlib : LibraryName,
                                            importc : "ffgky" .}

template defineReadKeyProc(name : expr, t : typeDesc, cfitsioType : int) =
    proc name*(fileObj : var FitsFile, keyName : string) : t =
        var status = 0
        if fitsReadKey(fileObj.file, cfitsioType,
                       keyName, cast[ptr char](addr(result)), nil,
                       addr(status)) != 0:
            raiseFitsException(status, "key \"" & keyName & "\"" &
                                       " in file \"" & fileObj.fileName & "\"")

defineReadKeyProc(readIntKey, int, tInt)
defineReadKeyProc(readInt64Key, int64, tLongLong)
defineReadKeyProc(readFloatKey, float64, tDouble)

proc readLogicKey*(fileObj : var FitsFile, keyName : string) : bool =
    result = (readIntKey(fileObj, keyName) != 0)

proc readStringKey*(fileObj : var FitsFile, keyName : string) : string =
    var status = 0
    var cResult : ValueStr

    if fitsReadKey(fileObj.file, tString,
                   keyName, cast[ptr char](addr(cResult)), nil,
                   addr(status)) != 0:
        raiseFitsException(status, "key \"" & keyName & "\"")

    result = $cResult

template defReadComplex(floatType : typeDesc,
                        complexType : typeDesc,
                        cfitsioType : int,
                        name : expr) =
    proc name*(fileObj : var FitsFile, keyName : string) : complexType =
        var status = 0
        var cResult : array[0..1, floatType]

        if fitsReadKey(fileObj.file, cfitsioType,
                       keyName, cast[ptr char](addr(cResult)), nil,
                       addr(status)) != 0:
            raiseFitsException(status, "key \"" & keyName & "\"")

        result.re = cResult[0]
        result.im = cResult[1]

defReadComplex(float32, Complex32, tComplex, readComplex32Key)
defReadComplex(float64, Complex64, tDblComplex, readComplex64Key)

#-------------------------------------------------------------------------------

proc fitsWriteKey(filePtr : InternalFitsStruct,
                  dataType : int,
                  keyName : cstring,
                  value : pointer,
                  comment : cstring,
                  status : ptr int) : int {. cdecl,
                                             dynlib : LibraryName,
                                             importc : "ffpky" .}

proc fitsUpdateKey(filePtr : InternalFitsStruct,
                   dataType : int,
                   keyName : cstring,
                   value : pointer,
                   comment : cstring,
                   status : ptr int) : int {. cdecl,
                                              dynlib : LibraryName,
                                              importc : "ffuky" .}

template defWriteKey(name : expr,
                     fitsFunc : expr,
                     dataType : typeDesc,
                     dtDataType : int) =

    proc name*(fileObj : var FitsFile,
               keyName : string,
               value : dataType,
               comment : string = "") =

        var status = 0
        var cValue : dataType = value

        if fitsFunc(fileObj.file, dtDataType, keyName, addr(cValue),
                    comment, addr(status)) != 0:
            raiseFitsException(status, "unable to write key \"" & keyName & "\"" &
                                       " in file \"" & fileObj.fileName & "\"")

defWriteKey(writeIntKey, fitsWriteKey, int, tInt)
defWriteKey(writeInt64Key, fitsWriteKey, int64, tLongLong)
defWriteKey(writeFloatKey, fitsWriteKey, float64, tDouble)

defWriteKey(updateIntKey, fitsUpdateKey, int, tInt)
defWriteKey(updateInt64Key, fitsUpdateKey, int64, tLongLong)
defWriteKey(updateFloatKey, fitsUpdateKey, float64, tDouble)

template defWriteStrKey(name : expr, fitsFunc : expr) =

    proc name*(fileObj : var FitsFile,
               keyName : string,
               value : string,
               comment : string = "") =

        var status = 0
        if fitsFunc(fileObj.file, tString, keyName, cstring(value),
                    comment, addr(status)) != 0:
            raiseFitsException(status, "unable to write key \"" & keyName & "\"" &
                                       " in file \"" & fileObj.fileName & "\"")

defWriteStrKey(writeStringKey, fitsWriteKey)
defWriteStrKey(updateStringKey, fitsUpdateKey)

#-------------------------------------------------------------------------------

proc fitsWriteKeyNull(fileObj : InternalFitsStruct,
                      keyName : cstring,
                      comment : cstring,
                      status : ptr int) : int {. cdecl,
                                                 dynlib : LibraryName,
                                                 importc : "ffpkyu" .}

proc fitsUpdateKeyNull(fileObj : InternalFitsStruct,
                       keyName : cstring,
                       comment : cstring,
                       status : ptr int) : int {. cdecl,
                                                  dynlib : LibraryName,
                                                  importc : "ffukyu" .}

template defWriteKeyNull(name : expr, fitsFunc : expr) =

    proc name*(fileObj : var FitsFile, keyName : string, comment : string) =
        var status = 0
        if fitsFunc(fileObj.file, keyName, comment, addr(status)) != 0:
            raiseFitsException(status, "unable to write key \"" & keyName & "\"" &
                                   " in file \"" & fileObj.fileName & "\"")

defWriteKeyNull(writeNullKey, fitsWriteKeyNull)
defWriteKeyNull(updateNullKey, fitsUpdateKeyNull)

#-------------------------------------------------------------------------------

proc fitsWriteComment(fileObj : InternalFitsStruct,
                      comment : cstring,
                      status : ptr int) : int {. cdecl,
                                                 dynlib : LibraryName,
                                                 importc : "ffpcom" .}

proc writeComment*(fileObj : var FitsFile, comment : string) =
    var status = 0
    if fitsWriteComment(fileObj.file, comment, addr(status)) != 0:
        raiseFitsException(status, "unable to write comment \"" & comment & "\"" &
                                   " in file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsModifyComment(fileObj : InternalFitsStruct,
                       keyName : cstring,
                       comment : cstring,
                       status : ptr int) : int {. cdecl,
                                                  dynlib : LibraryName,
                                                  importc : "ffmcom" .}

proc modifyComment*(fileObj : var FitsFile, keyName : string, comment : string) =
    var status = 0
    if fitsModifyComment(fileObj.file, keyName, comment, addr(status)) != 0:
        raiseFitsException(status, "unable to modify comment for key \"" & keyName &
                                   "\" in file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsRenameKey(fileObj : InternalFitsStruct,
                   oldName : cstring,
                   newName : cstring,
                   status : ptr int) : int {. cdecl,
                                              dynlib : LibraryName,
                                              importc : "ffmnam" .}

proc renameKey*(fileObj : var FitsFile, oldName : string, newName : string) =
    var status = 0
    if fitsRenameKey(fileObj.file, oldName, newName, addr(status)) != 0:
        raiseFitsException(status, "unable to rename key \"" & oldName & "\"" &
                                   " in file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsWriteKeyUnit(fileObj : InternalFitsStruct,
                      keyName : cstring,
                      unit : cstring,
                      status : ptr int) : int {. cdecl,
                                                 dynlib : LibraryName,
                                                 importc : "ffpunt" .}

proc writeKeyUnit*(fileObj : var FitsFile, keyName : string, unit : string) =
    var status = 0
    if fitsWriteKeyUnit(fileObj.file, keyName, unit, addr(status)) != 0:
        raiseFitsException(status, "unable to add a measure unit to key \"" &
                                   keyName & "\" in file \"" & fileObj.fileName &
                                   "\"")

#-------------------------------------------------------------------------------

proc fitsDeleteRecord(fileObj : InternalFitsStruct,
                      pos : int,
                      status : ptr int) : int {. cdecl,
                                                 dynlib : LibraryName,
                                                 importc : "ffdrec" .}

proc fitsDeleteKey(fileObj : InternalFitsStruct,
                   keyName : cstring,
                   status : ptr int) : int {. cdecl,
                                              dynlib : LibraryName,
                                              importc : "ffdkey" .}

proc deleteKey*(fileObj : var FitsFile, keyIndex : int) =
    ## Delete the key whose index is `keyIndex` (the first key has index 1)
    var status = 0
    if fitsDeleteRecord(fileObj.file, keyIndex, addr(status)) != 0:
        raiseFitsException(status, "unable to delete key at index " &
                                   $keyIndex & " in file \"" &
                                   fileObj.fileName & "\"")

proc deleteKey*(fileObj : var FitsFile, keyName : string) =
    var status = 0
    if fitsDeleteKey(fileObj.file, keyName, addr(status)) != 0:
        raiseFitsException(status, "unable to delete key \"" &
                                   keyName & "\" in file \"" &
                                   fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsWriteHistory(fileObj : InternalFitsStruct,
                      history : cstring,
                      status : ptr int) : int {. cdecl,
                                                 dynlib : LibraryName,
                                                 importc : "ffphis" .}

proc writeHistory*(fileObj : var FitsFile, history : string) =
    var status = 0
    if fitsWriteHistory(fileObj.file, history, addr(status)) != 0:
        raiseFitsException(status, "unable to write history \"" & history & "\"" &
                                   " in file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsWriteDate(fileObj : InternalFitsStruct,
                   status : ptr int) : int {. cdecl,
                                              dynlib : LibraryName,
                                              importc : "ffpdat" .}

proc writeDate*(fileObj : var FitsFile) =
    var status = 0
    if fitsWriteDate(fileObj.file, addr(status)) != 0:
        raiseFitsException(status, "unable to write the current date" &
                                   " in file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsReadKeyUnit(filePtr : InternalFitsStruct,
                     keyName : cstring,
                     unit : CommentStr,
                     status : ptr int) : int {. cdecl,
                                                dynlib : LibraryName,
                                                importc : "ffgunt" .}

proc readKeyUnit*(fileObj : var FitsFile, keyName : string) : string =
    var status = 0
    var unit : CommentStr
    if fitsReadKeyUnit(fileObj.file, keyName, unit, addr(status)) != 0:
        raiseFitsException(status, "key \"" & keyName & "\"" &
                                   " in file \"" & fileObj.fileName & "\"")

    result = $unit

#-------------------------------------------------------------------------------

proc fitsGetNumRows(filePtr : InternalFitsStruct,
                    num : ptr int,
                    status : ptr int) : int {. cdecl,
                                              dynlib : LibraryName,
                                              importc : "ffgnrw" .}

proc getNumberOfRows*(fileObj : var FitsFile) : int =
    var status = 0
    if fitsGetNumRows(fileObj.file, addr(result), addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsGetColNum(filePtr : InternalFitsStruct,
                   caseSen : int,
                   templ : cstring,
                   colNum : ptr int,
                   status : ptr int) : int {. cdecl,
                                              dynlib : Libraryname,
                                              importc : "ffgcno" .}

type
    CaseHandling* = enum
        PreserveCase, IgnoreCase

proc getColumnNumber*(fileObj : var FitsFile,
                      name : string,
                      caseHandling : CaseHandling = IgnoreCase) : int =
    var status = 0
    var caseSen : int
    case caseHandling
    of PreserveCase : caseSen = 1
    of IgnoreCase : caseSen = 0

    if fitsGetColNum(fileObj.file, caseSen, name, addr(result), addr(status)) != 0:
        raiseFitsException(status, "column \"" & name & "\"" &
                                   " in file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsGetNumCols(filePtr : InternalFitsStruct,
                    num : ptr int,
                    status : ptr int) : int {. cdecl,
                                              dynlib : LibraryName,
                                              importc : "ffgncl" .}

proc getNumberOfColumns*(fileObj : var FitsFile) : int =
    var status = 0
    var cResult : int = 0
    if fitsGetNumCols(fileObj.file, addr(cResult), addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileObj.fileName & "\"")

    result = cResult

#-------------------------------------------------------------------------------

proc fitsGetColType(filePtr : InternalFitsStruct,
                    colnum : int,
                    typecode : ptr int,
                    repeat : ptr int64,
                    width : ptr int64,
                    status : ptr int) : int {. cdecl,
                                               dynlib : LibraryName,
                                               importc : "ffgtclll" .}

type
    TableColumnInfo* = object
        dataType* : DataType
        repeatCount* : int64
        width* : int64

proc getColumnType*(fileObj : var FitsFile, colNum : int) : TableColumnInfo =
    var status = 0
    var typecode = 0
    var repeat : int64
    var width : int64

    if fitsGetColType(fileObj.file, colNum,
                      addr(typecode), addr(repeat), addr(width),
                      addr(status)) != 0:
        raiseFitsException(status, "column " & $colNum &
                                   ", file \"" & fileObj.fileName & "\"")

    result.dataType = codeToDataType(typecode)
    result.repeatCount = repeat
    result.width = width

#-------------------------------------------------------------------------------

proc fitsGetRowSize(filePtr : InternalFitsStruct,
                    nrows : ptr int,
                    status : ptr int) : int {. cdecl,
                                               dynlib : LibraryName,
                                               importc : "ffgrsz" .}

proc getOptimalNumberOfRowsForIO*(fileObj : var FitsFile) : int =
    var status = 0
    var cResult : int = 0
    if fitsGetRowSize(fileObj.file, addr(cResult), addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileObj.fileName & "\"")

    result = cResult

#-------------------------------------------------------------------------------

proc fitsReadCol(filePtr : InternalFitsStruct,
                 dataType : int,
                 colNum : int,
                 firstRow : int64,
                 firstElem : int64,
                 numOfElements : int64,
                 nullValue : ptr char,
                 destArray : ptr char,
                 anyNull : ptr int,
                 status : ptr int) : int {. cdecl,
                                            dynlib : LibraryName,
                                            importc : "ffgcv" .}

proc fitsReadColNull(filePtr : InternalFitsStruct,
                     dataType : int,
                     colNum : int,
                     firstRow : int64,
                     firstElem : int64,
                     numOfElements : int64,
                     destArray : ptr char,
                     nullArray : ptr bool,
                     anyNull : ptr int,
                     status : ptr int) : int {. cdecl,
                                                dynlib : LibraryName,
                                                importc : "ffgcf" .}

template defReadColumn(cfitsioType : int,
                       datatype : typeDesc,
                       name : expr,
                       null : expr) =

    # First implementation, with default value for NULL
    proc name*(fileObj : var FitsFile,
               colNum : int,
               firstRow : int,
               firstElem : int,
               numOfElements : int,
               dest : var openArray[datatype],
               destFirstIdx : int,
               nullValue : datatype) =

        var anyNull : int
        var status : int = 0
        var cNull = nullValue

        if fitsReadCol(fileObj.file,
                       cfitsioType,
                       colNum,
                       int64(firstRow),
                       int64(firstElem),
                       int64(numOfElements),
                       cast[ptr char](addr(cNull)),
                       cast[ptr char](addr(dest[destFirstIdx])),
                       addr(anyNull),
                       addr(status)) != 0:
            raiseFitsException(status, "column number " & $colNum &
                                       " in file \"" & fileObj.fileName & "\"")

    # Second implementation, with an explicit "destNull" argument
    proc name*(fileObj : var FitsFile,
               colNum : int,
               firstRow : int,
               firstElem : int,
               numOfElements : int,
               dest : var openArray[datatype],
               destNull : var openArray[bool],
               destFirstIdx : int) =

        var anyNull : int
        var status : int = 0
        var cDestNull : seq[int8]
        newSeq(cDestNull, numOfElements)

        if fitsReadColNull(fileObj.file,
                           cfitsioType,
                           colNum,
                           int64(firstRow),
                           int64(firstElem),
                           int64(numOfElements),
                           cast[ptr char](addr(dest[destFirstIdx])),
                           cast[ptr bool](addr(cDestNull[0])),
                           addr(anyNull),
                           addr(status)) != 0:
            raiseFitsException(status, "column number " & $colNum &
                                       " in file \"" & fileObj.fileName & "\"")

        # Convert the array of bytes initialized by CFITSIO into bool values
        for idx in 0 .. numOfElements-1:
            destNull[destFirstIdx + idx] = (cDestNull[idx] != 0)

    # Third implementation, similar to the first one but simpler
    proc name*(fileObj : var FitsFile,
               colNum : int,
               firstRow : int,
               firstElem : int,
               dest : var openArray[datatype],
               nullValue : datatype) =
        name(fileObj, colNum, firstRow, firstElem, len(dest),
             dest, low(dest), nullValue)

    # Fourth implementation, similar to the second one but simpler
    proc name*(fileObj : var FitsFile,
               colNum : int,
               firstRow : int,
               firstElem : int,
               dest : var openArray[datatype],
               destNull : var openArray[bool]) =
        name(fileObj, colNum, firstRow, firstElem, len(dest),
             dest, destNull, low(dest))

    # Two more implementations, the simplest ones

    proc name*(fileObj : var FitsFile,
               colNum : int,
               dest : var openArray[datatype],
               nullValue : datatype) =
        name(fileObj, colNum, 1, 1, dest, nullValue)

    proc name*(fileObj : var FitsFile,
               colNum : int,
               dest : var openArray[datatype],
               destNull : var openArray[bool]) =
        name(fileObj, colNum, 1, 1, dest, destNull)

defReadColumn(tSbyte, int8, readColumnOfInt8, 0'i8)
defReadColumn(tShort, int16, readColumnOfInt16, 0'i16)
defReadColumn(tInt, int32, readColumnOfInt32, 0'i32)
defReadColumn(tLongLong, int64, readColumnOfInt64, 0'i64)
defReadColumn(tFloat, float32, readColumnOfFloat32, 0.0'f32)
defReadColumn(tDouble, float64, readColumnOfFloat64, 0.0'f64)

#-------------------------------------------------------------------------------

proc fitsReadColStr(filePtr : InternalFitsStruct,
                    colnum : int,
                    firstrow : int64,
                    firstelem : int64,
                    nelements : int64,
                    nulstr : cstring,
                    dest : ptr cstring,
                    anynull : ptr int,
                    status : ptr int) : int {. cdecl,
                                               dynlib : LibraryName,
                                               importc : "ffgcvs" .}

proc readColumnOfString*(fileObj : var FitsFile,
                         colNum : int,
                         firstRow : int,
                         firstElem : int,
                         numOfElements : int,
                         dest : var openArray[string],
                         destFirstIdx : int,
                         nullValue : string = "") =

        var anyNull : int
        var status : int = 0

        let columnInfo = getColumnType(fileObj, colNum)

        var cDest : seq[ptr char]
        newSeq(cDest, numOfElements)
        for idx in 0 .. numOfElements - 1:
            cDest[idx] = createU(char, columnInfo.width)

        try:
            if fitsReadColStr(fileObj.file,
                              colNum,
                              int64(firstRow),
                              int64(firstElem),
                              int64(numOfElements),
                              nullValue,
                              cast[ptr cstring](addr(cDest[0])),
                              addr(anyNull),
                              addr(status)) != 0:
                raiseFitsException(status, "column number " & $colNum &
                                           " in file \"" & fileObj.fileName & "\"")

            for idx in 0 .. (numOfElements - 1):
                dest[destFirstIdx + idx] = $(cDest[idx])

        finally:
            for idx in 0 .. (numOfElements - 1):
                free(cDest[idx])

proc readColumnOfString*(fileObj : var FitsFile,
                         colNum : int,
                         firstRow : int,
                         firstElem : int,
                         dest : var openArray[string],
                         nullValue : string = "") =
    readColumnOfString(fileObj, colNum, firstRow, firstElem,
                       len(dest), dest, low(dest), nullValue)

proc readColumnOfString*(fileObj : var FitsFile,
                         colNum : int,
                         dest : var openArray[string],
                         nullValue : string = "") =
    readColumnOfString(fileObj, colNum, 1, 1, dest, nullValue)

#-------------------------------------------------------------------------------

proc fitsCreateTable(filePtr : InternalFitsStruct,
                     tableType : int,
                     naxis2 : int64,
                     tFields : int,
                     ttype : cstringArray,
                     tform : cstringArray,
                     tunit : cstringArray,
                     extname : cstring,
                     status : ptr int) : int {. cdecl,
                                                dynlib : LibraryName,
                                                importc : "ffcrtb" .}

type
    TableType* = range[AsciiTable..BinaryTable]

    TableColumn* = object
        name* : string
        dataType* : DataType
        width* : int
        repeatCount* : int
        unit* : string

proc tableTypeToInt(tableType : TableType) : int {. noSideEffect, inline .} =
    case tableType
    of AsciiTable: result = 1
    of BinaryTable: result = 2

proc createTable*(fileObj : var FitsFile,
                  tableType : TableType,
                  numOfElements : int64,
                  fields : openArray[TableColumn],
                  extname : string) =

    var status : int = 0
    var ttypeSeq : seq[string]
    var tformSeq : seq[string]
    var tunitSeq : seq[string]

    newSeq(ttypeSeq, len(fields))
    newSeq(tformSeq, len(fields))
    newSeq(tunitSeq, len(fields))

    for idx in countup(low(fields), high(fields)):
        let zeroIdx = idx - low(fields)
        ttypeSeq[zeroIdx] = fields[idx].name
        if fields[idx].dataType == dtString:
            tformSeq[zeroIdx] =
                $(fields[idx].width * fields[idx].repeatCount) &
                dataTypeChar(fields[idx].dataType) &
                $(fields[idx].width)
        else:
            tformSeq[zeroIdx] =
                dataTypeChar(fields[idx].dataType) & $(fields[idx].repeatCount)
        tunitSeq[zeroIdx] = fields[idx].unit

    var ttype = allocCStringArray(ttypeSeq)
    var tform = allocCStringArray(tformSeq)
    var tunit = allocCStringArray(tunitSeq)

    try:
        if fitsCreateTable(fileObj.file, tableTypeToInt(tableType),
                           numOfElements, len(fields),
                           ttype, tform, tunit,
                           extname, addr(status)) != 0:
            raiseFitsException(status, "unable to create table \"" &
                                       extname & "\" in file \"" &
                                       fileObj.fileName & "\"")
    finally:
        deallocCStringArray(ttype)
        deallocCStringArray(tform)
        deallocCStringArray(tunit)

#-------------------------------------------------------------------------------

proc fitsWriteColNull(filePtr : InternalFitsStruct,
                      dataType : int,
                      colNum : int,
                      firstRow : int64,
                      firstElem : int64,
                      numOfElements : int64,
                      sourceArray : pointer,
                      nullPtr : pointer,
                      status : ptr int) : int {. cdecl,
                                                 dynlib : LibraryName,
                                                 importc : "ffpcn" .}

template defWriteCol(name : expr, cfitsioType : int, dataType : typeDesc) =

    proc name*(fileObj : var FitsFile,
               colNum : int,
               firstRow : int,
               firstElem : int,
               numOfElements : int,
               values : var openArray[dataType], # We need "var" for using "addr"
               valueFirstIdx : int,
               nullPtr : ptr dataType = nil) =

        var status = 0

        if fitsWriteColNull(fileObj.file, cfitsioType, colNum,
                            int64(firstRow), int64(firstElem),
                            int64(numOfElements), addr(values[valueFirstIdx]),
                            nullPtr, addr(status)) != 0:
            raiseFitsException(status, "unable to write " & $numOfElements &
                                       "rows in column " & $colNum &
                                       "in file \"" &
                                       fileObj.fileName & "\"")

    proc name*(fileObj : var FitsFile,
               colNum : int,
               firstRow : int,
               firstElem : int,
               values : var openArray[dataType], # We need "var" for using "addr"
               nullPtr : ptr dataType = nil) =
        name(fileObj, colNum, firstRow, firstElem, len(values),
             values, low(values), nullPtr)

    proc name*(fileObj : var FitsFile,
               colNum : int,
               values : var openArray[dataType], # We need "var" for using "addr"
               nullPtr : ptr dataType = nil) =
        name(fileObj, colNum, 1, 1, values, nullPtr)

defWriteCol(writeColumnOfInt8, tSbyte, int8)
defWriteCol(writeColumnOfInt16, tShort, int16)
defWriteCol(writeColumnOfInt32, tInt, int32)
defWriteCol(writeColumnOfInt64, tLongLong, int64)
defWriteCol(writeColumnOfFloat32, tFloat, float32)
defWriteCol(writeColumnOfFloat64, tDouble, float64)

#-------------------------------------------------------------------------------

proc fitsWriteColStr(filePtr : InternalFitsStruct,
                     colNum : int,
                     firstRow : int64,
                     firstElem : int64,
                     numOfElements : int64,
                     sourceArray : pointer,
                     status : ptr int) : int {. cdecl,
                                                dynlib : LibraryName,
                                                importc : "ffpcls" .}

proc writeColumnOfString*(fileObj : var FitsFile,
                          colNum : int,
                          firstRow : int,
                          firstElem : int,
                          numOfElements : int,
                          values : var openArray[string],
                          valueFirstIdx : int,
                          nullPtr : ptr string = nil) =

        var status : int = 0

        # It is slightly inefficient to convert each string in
        # "values" into a cstring, as we're going to use only those
        # that go from index "valueFirstIdx" up to "valueFirstIdx +
        # numOfElements - 1". But the code is much simpler, and cases
        # where this matters are probably very rare.

        var cValues = allocCStringArray(values)
        try:
            if fitsWriteColStr(fileObj.file,
                               colNum,
                               int64(firstRow),
                               int64(firstElem),
                               int64(numOfElements),
                               cast[ptr cstring](addr(cValues[valueFirstIdx])),
                               addr(status)) != 0:
                raiseFitsException(status, "column number " & $colNum &
                                           " in file \"" & fileObj.fileName & "\"")

        finally:
            deallocCStringArray(cValues)

proc writeColumnOfString*(fileObj : var FitsFile,
                          colNum : int,
                          firstRow : int,
                          firstElem : int,
                          values : var openArray[string],
                          nullPtr : ptr string = nil) =
    writeColumnOfString(fileObj, colNum, firstRow, firstElem, len(values),
                        values, low(values), nullPtr)

proc writeColumnOfString*(fileObj : var FitsFile,
                          colNum : int,
                          values : var openArray[string],
                          nullPtr : ptr string = nil) =
    writeColumnOfString(fileObj, colNum, 1, 1, values, nullPtr)

#-------------------------------------------------------------------------------

proc fitsGetImgType(file : InternalFitsStruct,
                    bitpix : ptr int,
                    status : ptr int) : int {. cdecl,
                                               dynlib : LibraryName,
                                               importc : "ffgidt" .}

proc getImageType*(fileObj : var FitsFile) : int =
    var status = 0
    if fitsGetImgType(fileObj.file, addr(result), addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsGetImgDim(file : InternalFitsStruct,
                   naxis : ptr int,
                   status : ptr int) : int {. cdecl,
                                              dynlib : LibraryName,
                                              importc : "ffgidm" .}

proc getImageDimensions*(fileObj : var FitsFile) : int =
    var status = 0
    if fitsGetImgDim(fileObj.file, addr(result), addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsGetImgSizell(file : InternalFitsStruct,
                      maxdim : int,
                      naxes : ptr int64,
                      status : ptr int) : int {. cdecl,
                                                 dynlib : LibraryName,
                                                 importc : "ffgiszll" .}

proc getImageSize*(fileObj : var FitsFile) : seq[int64] =
    var status = 0
    newSeq(result, getImageDimensions(fileObj))
    if fitsGetImgSizell(fileObj.file, len(result),
                        addr(result[0]), addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

when isMainModule:
    import os

    # Here are a number of tests that check that the bindings are correct

    # Header reading test
    block:
        var f = openFile("./data/header.fits", ReadOnly)

        assert readStringKey(f, "STR") == "This is a string"
        assert readLogicKey(f, "LOGIC") == false
        assert readIntKey(f, "BYTE") == 128
        assert readInt64Key(f, "ULONG") == 2_147_483_648
        assert readInt64Key(f, "LONGLONG") == 4_611_686_018_427_387_904
        assert readFloatKey(f, "FLOAT") == 1.234568e+32
        assert readFloatKey(f, "DOUBLE") == 1.23456789e+124
        assert readComplex32Key(f, "CMPLX") == Complex32(re: 1.0'f32, im: 2.0'f32)
        assert readComplex64Key(f, "DBLCMPLX") == Complex64(re: 1.0e+123'f64,
                                                            im: 2.0e+124'f64)

        assert readKeyUnit(f, "USHORT") == "foo"

        closeFile(f)

    # Table reading test
    block:
        var f = openTable("./data/tables.fits", ReadOnly)

        assert moveToAbsHdu(f, 3) == BinaryTable
        assert getNumberOfColumns(f) == 7

        block:
            let numOfRows = getNumberOfRows(f)
            assert numOfRows == 9
            var numbers : seq[int32]
            newSeq(numbers, numOfRows)
            readColumnOfInt32(fileObj = f,
                              colNum = 5,
                              dest = numbers,
                              nullValue = 0'i32)

            assert numbers[0] == 1073741824
            assert numbers[8] == 1073741832

        assert moveToAbsHdu(f, 4) == BinaryTable
        assert getNumberOfColumns(f) == 2

        assert getColumnNumber(f, "float") == 1

        block:
            let numOfRows = getNumberOfRows(f)
            assert numOfRows == 3
            var numbers : seq[float64]
            newSeq(numbers, numOfRows)
            readColumnOfFloat64(fileObj = f,
                                colNum = 1,
                                dest = numbers,
                                nullValue = 0.0'f64)

            const tolerance = 1e-5
            assert abs(numbers[0] - 1.00000) < tolerance
            assert abs(numbers[1] - 2.71828) < tolerance
            assert abs(numbers[2] - 1.23456789e+6) / 1.0e6 < tolerance

        # Test for NULLs
        block:
            let numOfRows = getNumberOfRows(f)
            assert numOfRows == 3
            var numbers : seq[float64]
            var nulls : seq[bool]
            newSeq(numbers, numOfRows)
            newSeq(nulls, numOfRows)
            readColumnOfFloat64(fileObj = f,
                                colNum = 1,
                                dest = numbers,
                                destNull = nulls)

            assert nulls[0] == false
            assert nulls[1] == false
            assert nulls[2] == false

        # Reading a column of strings requires some complicated
        # machinery, so we test this separately
        assert moveToAbsHdu(f, 6) == BinaryTable
        assert getNumberOfColumns(f) == 1

        block:
            let numOfRows = getNumberOfRows(f)
            assert numOfRows == 9
            var strings : seq[string]
            newSeq(strings, numOfRows)
            readColumnOfString(fileObj = f,
                               colNum = 1,
                               dest = strings,
                               nullValue = "")

            assert strings[0] == "Fyodor"
            assert strings[8] == "Ilyusha"

        closeFile(f)

    # Image reading test
    block:
        var f = openImage("./data/photo.fits", ReadOnly)

        assert getImageType(f) == 8
        assert getImageDimensions(f) == 2
        assert getImageSize(f) == @[223'i64, 229'i64]

        closeFile(f)

    # File/table creation test
    block:
        var f = createFile(os.joinPath(os.getTempDir(), "test.fits"))
        let fields : array[3, TableColumn] =
            [TableColumn(name: "INT", dataType: dtInt32, width: 10,
                         repeatCount: 1, unit: "counts"),
             TableColumn(name: "STRING", dataType: dtString, width: 40,
                         repeatCount: 1, unit: ""),
             TableColumn(name: "DOUBLE", dataType: dtFloat64, width: 15,
                         repeatCount: 3, unit: "K/V")]
        createTable(f, BinaryTable, 3, fields, "TEST")

        writeIntKey(f, "KEYINT", 12, "this is a comment")
        assert readIntKey(f, "KEYINT") == 12

        writeFloatKey(f, "KEYFLT", 123.0, "and this too")
        assert readFloatKey(f, "KEYFLT") == 123.0

        updateIntKey(f, "KEYINT", 17, "comment!")
        assert readIntKey(f, "KEYINT") == 17

        # There isn't an easy way to check that the comment has been
        # written. However, just checking that the code does not
        # segfault nor throws exceptions is already a check! ;-)
        writeComment(f, "This is a comment")

        block:
            var values = [1'i32, 2'i32, 3'i32, 4'i32, 5'i32]
            writeColumnOfInt32(fileObj = f,
                               colNum = 1,
                               values = values)

            var checkValues : array[low(values) .. high(values), int32]
            readColumnOfInt32(fileObj = f,
                              colNum = 1,
                              dest = checkValues,
                              nullValue = 0'i32)

            for idx in low(values) .. high(values):
                assert values[idx] == checkValues[idx]

        block:
            var values = ["a", "bb", "ccc", "dddd", "eeeee"]
            writeColumnOfString(fileObj = f, colNum = 2, values = values)

            var checkValues : array[low(values) .. high(values), string]
            readColumnOfString(fileObj = f,
                               colNum = 2,
                               dest = checkValues)

            for idx in low(values) .. high(values):
                assert values[idx] == checkValues[idx]

        deleteFile(f)
