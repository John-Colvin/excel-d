/**
	MemoryManager.D

	Ported from MemoryManager.cpp by Laeeth Isharc
//
// Platform:    Microsoft Windows
//
///***************************************************************************
*/
module xlld.memorymanager;

import xlld.sdk.xlcall: XLOPER12, LPXLOPER12;
import xlld.any: Any;
import std.experimental.allocator.building_blocks.allocator_list: AllocatorList;
import std.experimental.allocator.mallocator: Mallocator;
import std.experimental.allocator.building_blocks.region: Region;
import std.algorithm.comparison: max;
import std.traits: isArray;
import std.meta: allSatisfy;

import std.experimental.allocator.building_blocks.stats_collector;

///
alias Allocator = StatsCollector!(Mallocator, Options.bytesUsed);

Allocator allocator;
///
alias AutoFreeAllocator = StatsCollector!(Mallocator, Options.bytesUsed);

AutoFreeAllocator autoFreeAllocator;

///
alias MemoryPool = StatsCollector!(AllocatorList!((size_t n) => Region!Mallocator(max(n, size_t(1024 * 1024))), Mallocator), Options.bytesUsed);

///
MemoryPool gTempAllocator;

///
T[][] makeArray2D(T, A)(ref A allocator, ref XLOPER12 oper) {
    import xlld.conv.from: isMulti;
    import std.experimental.allocator: makeMultidimensionalArray;
    with(oper.val.array) return
        isMulti(oper) ?
        allocator.makeMultidimensionalArray!T(rows, columns) :
        typeof(return).init;
}

/// the function called by the Excel callback
void autoFree(LPXLOPER12 arg) nothrow {
    import xlld.sdk.framework: freeXLOper;
    freeXLOper(arg, autoFreeAllocator);
}

///
struct AllocatorContext(A) {
    ///
    A* _allocator_;

    ///
    this(ref A allocator) {
        _allocator_ = &allocator;
    }

    ///
    auto any(T)(auto ref T value, in string file = __FILE__, in size_t line = __LINE__) {
        import xlld.any: _any = any;
        return _any(value, *_allocator_, file, line);
    }

    ///
    auto fromXlOper(T, U)(U oper) {
        import xlld.conv.from: convFromXlOper = fromXlOper;
        return convFromXlOper!T(oper, _allocator_);
    }

    ///
    auto toXlOper(T)(T val) {
        import xlld.conv: convToXlOper = toXlOper;
        return convToXlOper(val, _allocator_);
    }

    version(unittest) {
        ///
        auto toSRef(T)(T val) {
            import xlld.test.util: toSRef_ = toSRef;
            return toSRef_(val, _allocator_);
        }
    }
}

///
auto allocatorContext(A)(ref A allocator) {
    return AllocatorContext!A(allocator);
}
