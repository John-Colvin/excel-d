/**
   Utility functions for writing XLLs
 */
module xlld.sdk.framework;


import xlld.sdk.xlcall;
import std.stdio;

struct DebugOutput
{
    static void write(Args ...)(Args args)
    {
        import xlld.sdk.xll : log;
        log(args);
    }
}

DebugOutput debugOutput;

/**
        Will free any malloc'd memory associated with the given
        LPXLOPER, assuming it has any memory associated with it

   Parameters:

        LPXLOPER pxloper    Pointer to the XLOPER whose associated
*/
void freeXLOper(T, A)(T pxloper, ref A allocator) nothrow
    if(is(T == LPXLOPER) || is(T == LPXLOPER12))
{

    import xlld.sdk.xll : log;
    void report() nothrow
    {
        try
        {
            //allocator.reportPerCallStatistics(debugOutput);
            //allocator.reportStatistics(debugOutput);
        }
        catch(Exception e) { log(e.msg); }
    }

    report();

    //log(pxloper.xltype & ~XlType.xlbitDLLFree);

    import std.experimental.allocator: dispose;
    switch (pxloper.xltype & ~XlType.xlbitDLLFree) with(XlType) {
        case xltypeStr:
            if (pxloper.val.str !is null) {
                void* bytesPtr = pxloper.val.str;
                const numBytes = (pxloper.val.str[0] + 1) * wchar.sizeof;
                allocator.dispose(bytesPtr[0 .. numBytes]);
                log("str ", bytesPtr, " ", numBytes);
            }
            break;
        case xltypeRef:
            if (pxloper.val.mref.lpmref !is null)
            {
                allocator.dispose(pxloper.val.mref.lpmref);
                log("Ref ", pxloper.val.mref.lpmref);
            }
            break;
        case xltypeMulti:
            log(pxloper.val.array.rows, " x ", pxloper.val.array.columns);
            auto cxloper = pxloper.val.array.rows * pxloper.val.array.columns;
            const numOpers = cxloper;
            if (pxloper.val.array.lparray !is null)
            {
                auto pxloperFree = pxloper.val.array.lparray;
                while (cxloper > 0)
                {
                    freeXLOper(pxloperFree, allocator);
                    pxloperFree++;
                    cxloper--;
                }
                allocator.dispose(pxloper.val.array.lparray[0 .. numOpers]);
                log("Multi ", pxloper.val.array.lparray, " ", numOpers);
            }
            break;
        case xltypeBigData:
            if (pxloper.val.bigdata.h.lpbData !is null)
            {
                allocator.dispose(pxloper.val.bigdata.h.lpbData);
                log("BigData ", pxloper.val.bigdata.h.lpbData);
            }
            break;
        default: // todo: add error handling
            break;
    }

    report();

    //log("\n");
}

@("Free regular XLOPER")
unittest {
    import xlld.memorymanager: allocator;
    XLOPER oper;
    freeXLOper(&oper, allocator);
}

@("Free XLOPER12")
unittest {
    import xlld.memorymanager: allocator;
    XLOPER12 oper;
    freeXLOper(&oper, allocator);
}

/**
   Wrapper for the Excel12 function that allows passing D arrays

   Purpose:
        A fancy wrapper for the Excel12() function. It also
        does the following:

        (1) Checks that none of the LPXLOPER12 arguments are 0,
            which would indicate that creating a temporary XLOPER12
            has failed. In this case, it doesn't call Excel12
            but it does print a debug message.
        (2) If an error occurs while calling Excel12,
            print a useful debug message.
        (3) When done, free all temporary memory.

        #1 and #2 require _DEBUG to be defined.

   Parameters:

        int xlfn            Function number (xl...) to call
        LPXLOPER12 pxResult Pointer to a place to stuff the result,
                            or 0 if you don't care about the result.
        int count           Number of arguments
        ...                 (all LPXLOPER12s) - the arguments.

   Returns:

        A return code (Some of the xlret... values, as defined
        in XLCALL.H, OR'ed together).

   Comments:
*/

int Excel12f(int xlfn, LPXLOPER12 pxResult, in LPXLOPER12[] args...) nothrow @nogc
{
    import xlld.sdk.xlcallcpp: Excel12v;
    import std.algorithm: all;

    assert(args.all!(a => a !is null));
    return Excel12v(xlfn, pxResult, cast(int)args.length, cast(LPXLOPER12*)args.ptr);
}

///
int Excel12f(int xlfn, LPXLOPER12 result, in XLOPER12[] args...) nothrow {

    auto ptrArgs = new const(XLOPER12)*[args.length];

    foreach(i, ref arg; args)
        ptrArgs[i] = () @trusted { return &arg; }();

    return Excel12f(xlfn, result, ptrArgs);
}

///
int Excel12f(int xlfn, LPXLOPER12 pxResult) nothrow @nogc
{
    return Excel12f(xlfn, pxResult, LPXLOPER12[].init);
}
