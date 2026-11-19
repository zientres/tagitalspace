// Standard library for funC
//

@pure
fun cons<X>(head: X, tail: tuple): tuple
    asm "CONS";
@pure
fun uncons<X>(list: tuple): (X, tuple)
    asm "UNCONS";
@pure
fun listNext<X>(list: tuple): (tuple, X)
    asm( -> 1 0) "UNCONS";
@pure
fun car<X>(list: tuple): X
    asm "CAR";
@pure
fun cdr(list: tuple): tuple
    asm "CDR";
@pure
fun emptyTuple(): tuple
    asm "NIL";
@pure
fun tpush<X>(t: tuple, value: X): tuple
    asm "TPUSH";
@pure
fun tuple.tpush<X>(mutate self, value: X): void
    asm "TPUSH";
@pure
fun single<X>(x: X): [X]
    asm "SINGLE";
@pure
fun unsingle<X>(t: [X]): X
    asm "UNSINGLE";
@pure
fun pair<X, Y>(x: X, y: Y): [X, Y]
    asm "PAIR";
@pure
fun unpair<X, Y>(t: [X, Y]): (X, Y)
    asm "UNPAIR";
@pure
fun triple<X, Y, Z>(x: X, y: Y, z: Z): [X, Y, Z]
    asm "TRIPLE";
@pure
fun untriple<X, Y, Z>(t: [X, Y, Z]): (X, Y, Z)
    asm "UNTRIPLE";
@pure
fun tuple4<X, Y, Z, W>(x: X, y: Y, z: Z, w: W): [X, Y, Z, W]
    asm "4 TUPLE";
@pure
fun untuple4<X, Y, Z, W>(t: [X, Y, Z, W]): (X, Y, Z, W)
    asm "4 UNTUPLE";
@pure
fun first<X>(t: tuple): X
    asm "FIRST";
@pure
fun second<X>(t: tuple): X
    asm "SECOND";
@pure
fun third<X>(t: tuple): X
    asm "THIRD";
@pure
fun fourth<X>(t: tuple): X
    asm "3 INDEX";
@pure
fun pairFirst<X, Y>(p: [X, Y]): X
    asm "FIRST";
@pure
fun pairSecond<X, Y>(p: [X, Y]): Y
    asm "SECOND";
@pure
fun tripleFirst<X, Y, Z>(p: [X, Y, Z]): X
    asm "FIRST";
@pure
fun tripleSecond<X, Y, Z>(p: [X, Y, Z]): Y
    asm "SECOND";
@pure
fun tripleThird<X, Y, Z>(p: [X, Y, Z]): Z
    asm "THIRD";
@pure
fun null<X>(): X
    asm "PUSHNULL";
fun X.impureTouch<X>(mutate self): void
    asm "NOP";

@pure
fun now(): int
    asm "NOW";
@pure
fun myAddress(): address
    asm "MYADDR";
@pure
fun getBalance(): [int, cell]
    asm "BALANCE";
@pure
fun curLt(): int
    asm "LTIME";
@pure
fun blockLt(): int
    asm "BLOCKLT";

@pure
fun cellHash(c: cell): int
    asm "HASHCU";
@pure
fun sliceHash(s: slice): int
    asm "HASHSU";
@pure
fun stringHash(s: slice): int
    asm "SHA256U";

@pure
fun checkSignature(hash: int, signature: slice, publicKey: int): int
    asm "CHKSIGNU";
@pure
fun checkDataSignature(data: slice, signature: slice, publicKey: int): int
    asm "CHKSIGNS";

fun computeDataSize(c: cell, maxCells: int): (int, int, int)
    asm "CDATASIZE";
fun sliceComputeDataSize(s: slice, maxCells: int): (int, int, int)
    asm "SDATASIZE";
@pure
fun isComputeDataSize(c: cell, maxCells: int): (int, int, int, int)
    asm "CDATASIZEQ NULLSWAPIFNOT2 NULLSWAPIFNOT";
@pure
fun isSliceComputeDataSize(c: cell, maxCells: int): (int, int, int, int)
    asm "SDATASIZEQ NULLSWAPIFNOT2 NULLSWAPIFNOT";

// () throw_if(int excno, int cond) impure asm "THROWARGIF";

fun dumpStack(): void
    asm "DUMPSTK";

@pure
fun getData(): cell
    asm "c4 PUSH";
fun setData(c: cell): void
    asm "c4 POP";
fun getC3(): continuation
    asm "c3 PUSH";
fun setC3(c: continuation): void
    asm "c3 POP";
fun bless(s: slice): continuation
    asm "BLESS";

fun acceptMessage(): void
    asm "ACCEPT";
fun setGasLimit(limit: int): void
    asm "SETGASLIMIT";
fun commit(): void
    asm "COMMIT";
fun buyGas(gram: int): void
    asm "BUYGAS";

@pure
fun min(x: int, y: int): int
    asm "MIN";
@pure
fun max(x: int, y: int): int
    asm "MAX";
@pure
fun minmax(x: int, y: int): (int, int)
    asm "MINMAX";
@pure
fun abs(x: int): int
    asm "ABS";

@pure
fun beginParse(c: cell): slice
    asm "CTOS";
fun endParse(s: slice): void
    asm "ENDS";
@pure
fun slice.loadRef(mutate self): cell
    asm( -> 1 0) "LDREF";
@pure
fun preloadRef(s: slice): cell
    asm "PLDREF";
// (slice, int) ~load_int(slice s, int len) asm(s len -> 1 0) "LDIX";
// (slice, int) ~load_uint(slice s, int len) asm( -> 1 0) "LDUX";
// int preload_int(slice s, int len) asm "PLDIX";
// int preload_uint(slice s, int len) asm "PLDUX";
// (slice, slice) load_bits(slice s, int len) asm(s len -> 1 0) "LDSLICEX";
// slice preload_bits(slice s, int len) asm "PLDSLICEX";
@pure
fun slice.loadGrams(mutate self): int
    asm( -> 1 0) "LDGRAMS";
@pure
fun skipBits(s: slice, len: int): slice
    asm "SDSKIPFIRST";
@pure
fun slice.skipBits(mutate self, len: int): void
    asm "SDSKIPFIRST";
@pure
fun firstBits(s: slice, len: int): slice
    asm "SDCUTFIRST";
@pure
fun skipLastBits(s: slice, len: int): slice
    asm "SDSKIPLAST";
@pure
fun slice.skipLastBits(mutate self, len: int): void
    asm "SDSKIPLAST";
@pure
fun sliceLast(s: slice, len: int): slice
    asm "SDCUTLAST";
@pure
fun slice.loadDict(mutate self): cell
    asm( -> 1 0) "LDDICT";
@pure
fun preloadDict(s: slice): cell
    asm "PLDDICT";
@pure
fun skipDict(s: slice): slice
    asm "SKIPDICT";

@pure
fun slice.loadMaybeRef(mutate self): cell
    asm( -> 1 0) "LDOPTREF";
@pure
fun preloadMaybeRef(s: slice): cell
    asm "PLDOPTREF";
@pure
fun storeMaybeRef(b: builder, c: cell): builder
    asm(c b) "STOPTREF";

@pure
fun cellDepth(c: cell): int
    asm "CDEPTH";

@pure
fun sliceRefs(s: slice): int
    asm "SREFS";
@pure
fun sliceBits(s: slice): int
    asm "SBITS";
@pure
fun sliceBitsRefs(s: slice): (int, int)
    asm "SBITREFS";
@pure
fun isSliceEmpty(s: slice): int
    asm "SEMPTY";
@pure
fun isSliceDataEmpty(s: slice): int
    asm "SDEMPTY";
@pure
fun isSliceRefsEmpty(s: slice): int
    asm "SREMPTY";
@pure
fun sliceDepth(s: slice): int
    asm "SDEPTH";

@pure
fun builderRefs(b: builder): int
    asm "BREFS";
@pure
fun builderBits(b: builder): int
    asm "BBITS";
@pure
fun builderDepth(b: builder): int
    asm "BDEPTH";

@pure
fun beginCell(): builder
    asm "NEWC";
@pure
fun endCell(b: builder): cell
    asm "ENDC";
@pure
fun storeRef(b: builder, c: cell): builder
    asm(c b) "STREF";
// builder store_uint(builder b, int x, int len) asm(x b len) "STUX";
// builder store_int(builder b, int x, int len) asm(x b len) "STIX";
@pure
fun storeSlice(b: builder, s: slice): builder
    asm "STSLICER";
@pure
fun storeGrams(b: builder, x: int): builder
    asm "STGRAMS";
@pure
fun storeDict(b: builder, c: cell): builder
    asm(c b) "STDICT";

@pure
fun slice.loadMsgAddr(mutate self): address
    asm( -> 1 0) "LDMSGADDR";
@pure
fun parseAddr(s: slice): tuple
    asm "PARSEMSGADDR";
@pure
fun parseStdAddr(s: slice): (int, int)
    asm "REWRITESTDADDR";
@pure
fun parseVarAddr(s: slice): (int, slice)
    asm "REWRITEVARADDR";

@pure
fun idictSetRef(dict: cell, keyLen: int, index: int, value: cell): cell
    asm(value index dict keyLen) "DICTISETREF";
@pure
fun cell.idictSetRef(mutate self, keyLen: int, index: int, value: cell): void
    asm(value index self keyLen) "DICTISETREF";
@pure
fun udictSetRef(dict: cell, keyLen: int, index: int, value: cell): cell
    asm(value index dict keyLen) "DICTUSETREF";
@pure
fun cell.udictSetRef(mutate self, keyLen: int, index: int, value: cell): void
    asm(value index self keyLen) "DICTUSETREF";
@pure
fun idictGetRef(dict: cell, keyLen: int, index: int): cell
    asm(index dict keyLen) "DICTIGETOPTREF";
@pure
fun isIdictGetRef(dict: cell, keyLen: int, index: int): (cell, int)
    asm(index dict keyLen) "DICTIGETREF" "NULLSWAPIFNOT";
@pure
fun isUdictGetRef(dict: cell, keyLen: int, index: int): (cell, int)
    asm(index dict keyLen) "DICTUGETREF" "NULLSWAPIFNOT";
@pure
fun idictSetGetRef(dict: cell, keyLen: int, index: int, value: cell): (cell, cell)
    asm(value index dict keyLen) "DICTISETGETOPTREF";
@pure
fun udictSetGetRef(dict: cell, keyLen: int, index: int, value: cell): (cell, cell)
    asm(value index dict keyLen) "DICTUSETGETOPTREF";
@pure
fun isIdictDelete(dict: cell, keyLen: int, index: int): (cell, int)
    asm(index dict keyLen) "DICTIDEL";
@pure
fun isUdictDelete(dict: cell, keyLen: int, index: int): (cell, int)
    asm(index dict keyLen) "DICTUDEL";
@pure
fun isIdictGet(dict: cell, keyLen: int, index: int): (slice, int)
    asm(index dict keyLen) "DICTIGET" "NULLSWAPIFNOT";
@pure
fun isUdictGet(dict: cell, keyLen: int, index: int): (slice, int)
    asm(index dict keyLen) "DICTUGET" "NULLSWAPIFNOT";
@pure
fun isIdictDeleteGet(dict: cell, keyLen: int, index: int): (cell, slice, int)
    asm(index dict keyLen) "DICTIDELGET" "NULLSWAPIFNOT";
@pure
fun isUdictDeleteGet(dict: cell, keyLen: int, index: int): (cell, slice, int)
    asm(index dict keyLen) "DICTUDELGET" "NULLSWAPIFNOT";
@pure
fun cell.isIdictDeleteGet(mutate self, keyLen: int, index: int): (slice, int)
    asm(index self keyLen) "DICTIDELGET" "NULLSWAPIFNOT";
@pure
fun cell.isUdictDeleteGet(mutate self, keyLen: int, index: int): (slice, int)
    asm(index self keyLen) "DICTUDELGET" "NULLSWAPIFNOT";
@pure
fun udictSet(dict: cell, keyLen: int, index: int, value: slice): cell
    asm(value index dict keyLen) "DICTUSET";
@pure
fun cell.udictSet(mutate self, keyLen: int, index: int, value: slice): void
    asm(value index self keyLen) "DICTUSET";
@pure
fun idictSet(dict: cell, keyLen: int, index: int, value: slice): cell
    asm(value index dict keyLen) "DICTISET";
@pure
fun cell.idictSet(mutate self, keyLen: int, index: int, value: slice): void
    asm(value index self keyLen) "DICTISET";
@pure
fun dictSet(dict: cell, keyLen: int, index: slice, value: slice): cell
    asm(value index dict keyLen) "DICTSET";
@pure
fun cell.dictSet(mutate self, keyLen: int, index: slice, value: slice): void
    asm(value index self keyLen) "DICTSET";
@pure
fun isUdictAdd(dict: cell, keyLen: int, index: int, value: slice): (cell, int)
    asm(value index dict keyLen) "DICTUADD";
@pure
fun isUdictReplace(dict: cell, keyLen: int, index: int, value: slice): (cell, int)
    asm(value index dict keyLen) "DICTUREPLACE";
@pure
fun isIdictAdd(dict: cell, keyLen: int, index: int, value: slice): (cell, int)
    asm(value index dict keyLen) "DICTIADD";
@pure
fun isIdictReplace(dict: cell, keyLen: int, index: int, value: slice): (cell, int)
    asm(value index dict keyLen) "DICTIREPLACE";
@pure
fun udictSetBuilder(dict: cell, keyLen: int, index: int, value: builder): cell
    asm(value index dict keyLen) "DICTUSETB";
@pure
fun cell.udictSetBuilder(mutate self, keyLen: int, index: int, value: builder): void
    asm(value index self keyLen) "DICTUSETB";
@pure
fun idictSetBuilder(dict: cell, keyLen: int, index: int, value: builder): cell
    asm(value index dict keyLen) "DICTISETB";
@pure
fun cell.idictSetBuilder(mutate self, keyLen: int, index: int, value: builder): void
    asm(value index self keyLen) "DICTISETB";
@pure
fun dictSetBuilder(dict: cell, keyLen: int, index: slice, value: builder): cell
    asm(value index dict keyLen) "DICTSETB";
@pure
fun cell.dictSetBuilder(mutate self, keyLen: int, index: slice, value: builder): void
    asm(value index self keyLen) "DICTSETB";
@pure
fun isUdictAddBuilder(dict: cell, keyLen: int, index: int, value: builder): (cell, int)
    asm(value index dict keyLen) "DICTUADDB";
@pure
fun isUdictReplaceBuilder(dict: cell, keyLen: int, index: int, value: builder): (cell, int)
    asm(value index dict keyLen) "DICTUREPLACEB";
@pure
fun isIdictAddBuilder(dict: cell, keyLen: int, index: int, value: builder): (cell, int)
    asm(value index dict keyLen) "DICTIADDB";
@pure
fun isIdictReplaceBuilder(dict: cell, keyLen: int, index: int, value: builder): (cell, int)
    asm(value index dict keyLen) "DICTIREPLACEB";
@pure
fun udictDeleteGetMin(dict: cell, keyLen: int): (cell, int, slice, int)
    asm(-> 0 2 1 3) "DICTUREMMIN" "NULLSWAPIFNOT2";
@pure
fun cell.`udict::delete_get_min`(mutate self, keyLen: int): (int, slice, int)
    asm(-> 0 2 1 3) "DICTUREMMIN" "NULLSWAPIFNOT2";
@pure
fun idictDeleteGetMin(dict: cell, keyLen: int): (cell, int, slice, int)
    asm(-> 0 2 1 3) "DICTIREMMIN" "NULLSWAPIFNOT2";
@pure
fun cell.`idict::delete_get_min`(mutate self, keyLen: int): (int, slice, int)
    asm(-> 0 2 1 3) "DICTIREMMIN" "NULLSWAPIFNOT2";
@pure
fun dictDeleteGetMin(dict: cell, keyLen: int): (cell, slice, slice, int)
    asm(-> 0 2 1 3) "DICTREMMIN" "NULLSWAPIFNOT2";
@pure
fun cell.`dict::delete_get_min`(mutate self, keyLen: int): (slice, slice, int)
    asm(-> 0 2 1 3) "DICTREMMIN" "NULLSWAPIFNOT2";
@pure
fun udictDeleteGetMax(dict: cell, keyLen: int): (cell, int, slice, int)
    asm(-> 0 2 1 3) "DICTUREMMAX" "NULLSWAPIFNOT2";
@pure
fun cell.`udict::delete_get_max`(mutate self, keyLen: int): (int, slice, int)
    asm(-> 0 2 1 3) "DICTUREMMAX" "NULLSWAPIFNOT2";
@pure
fun idictDeleteGetMax(dict: cell, keyLen: int): (cell, int, slice, int)
    asm(-> 0 2 1 3) "DICTIREMMAX" "NULLSWAPIFNOT2";
@pure
fun cell.`idict::delete_get_max`(mutate self, keyLen: int): (int, slice, int)
    asm(-> 0 2 1 3) "DICTIREMMAX" "NULLSWAPIFNOT2";
@pure
fun dictDeleteGetMax(dict: cell, keyLen: int): (cell, slice, slice, int)
    asm(-> 0 2 1 3) "DICTREMMAX" "NULLSWAPIFNOT2";
@pure
fun cell.`dict::delete_get_max`(mutate self, keyLen: int): (slice, slice, int)
    asm(-> 0 2 1 3) "DICTREMMAX" "NULLSWAPIFNOT2";
@pure
fun isUdictGetMin(dict: cell, keyLen: int): (int, slice, int)
    asm (-> 1 0 2) "DICTUMIN" "NULLSWAPIFNOT2";
@pure
fun isUdictGetMax(dict: cell, keyLen: int): (int, slice, int)
    asm (-> 1 0 2) "DICTUMAX" "NULLSWAPIFNOT2";
@pure
fun isUdictGetMinRef(dict: cell, keyLen: int): (int, cell, int)
    asm (-> 1 0 2) "DICTUMINREF" "NULLSWAPIFNOT2";
@pure
fun isUdictGetMaxRef(dict: cell, keyLen: int): (int, cell, int)
    asm (-> 1 0 2) "DICTUMAXREF" "NULLSWAPIFNOT2";
@pure
fun isIdictGetMin(dict: cell, keyLen: int): (int, slice, int)
    asm (-> 1 0 2) "DICTIMIN" "NULLSWAPIFNOT2";
@pure
fun isIdictGetMax(dict: cell, keyLen: int): (int, slice, int)
    asm (-> 1 0 2) "DICTIMAX" "NULLSWAPIFNOT2";
@pure
fun isIdictGetMinRef(dict: cell, keyLen: int): (int, cell, int)
    asm (-> 1 0 2) "DICTIMINREF" "NULLSWAPIFNOT2";
@pure
fun isIdictGetMaxRef(dict: cell, keyLen: int): (int, cell, int)
    asm (-> 1 0 2) "DICTIMAXREF" "NULLSWAPIFNOT2";
@pure
fun isUdictGetNext(dict: cell, keyLen: int, pivot: int): (int, slice, int)
    asm(pivot dict keyLen -> 1 0 2) "DICTUGETNEXT" "NULLSWAPIFNOT2";
@pure
fun isUdictGetNexteq(dict: cell, keyLen: int, pivot: int): (int, slice, int)
    asm(pivot dict keyLen -> 1 0 2) "DICTUGETNEXTEQ" "NULLSWAPIFNOT2";
@pure
fun isUdictGetPrev(dict: cell, keyLen: int, pivot: int): (int, slice, int)
    asm(pivot dict keyLen -> 1 0 2) "DICTUGETPREV" "NULLSWAPIFNOT2";
@pure
fun isUdictGetPreveq(dict: cell, keyLen: int, pivot: int): (int, slice, int)
    asm(pivot dict keyLen -> 1 0 2) "DICTUGETPREVEQ" "NULLSWAPIFNOT2";
@pure
fun isIdictGetNext(dict: cell, keyLen: int, pivot: int): (int, slice, int)
    asm(pivot dict keyLen -> 1 0 2) "DICTIGETNEXT" "NULLSWAPIFNOT2";
@pure
fun isIdictGetNexteq(dict: cell, keyLen: int, pivot: int): (int, slice, int)
    asm(pivot dict keyLen -> 1 0 2) "DICTIGETNEXTEQ" "NULLSWAPIFNOT2";
@pure
fun isIdictGetPrev(dict: cell, keyLen: int, pivot: int): (int, slice, int)
    asm(pivot dict keyLen -> 1 0 2) "DICTIGETPREV" "NULLSWAPIFNOT2";
@pure
fun isIdictGetPreveq(dict: cell, keyLen: int, pivot: int): (int, slice, int)
    asm(pivot dict keyLen -> 1 0 2) "DICTIGETPREVEQ" "NULLSWAPIFNOT2";
@pure
fun newDict(): cell
    asm "NEWDICT";
@pure
fun isDictEmpty(c: cell): int
    asm "DICTEMPTY";

@pure
fun isPfxdictGet(dict: cell, keyLen: int, key: slice): (slice, slice, slice, int)
    asm(key dict keyLen) "PFXDICTGETQ" "NULLSWAPIFNOT2";
@pure
fun isPfxdictSet(dict: cell, keyLen: int, key: slice, value: slice): (cell, int)
    asm(value key dict keyLen) "PFXDICTSET";
@pure
fun isPfxdictDelete(dict: cell, keyLen: int, key: slice): (cell, int)
    asm(key dict keyLen) "PFXDICTDEL";

@pure
fun configParam(x: int): cell
    asm "CONFIGOPTPARAM";
@pure
fun isCellNull(c: cell): int
    asm "ISNULL";

fun rawReserve(amount: int, mode: int): void
    asm "RAWRESERVE";
fun rawReserveExtra(amount: int, extraAmount: cell, mode: int): void
    asm "RAWRESERVEX";
fun sendRawMessage(msg: cell, mode: int): void
    asm "SENDRAWMSG";
fun setCode(newCode: cell): void
    asm "SETCODE";

fun random(): int
    asm "RANDU256";
fun rand(range: int): int
    asm "RAND";
fun getSeed(): int
    asm "RANDSEED";
fun setSeed(): int
    asm "SETRAND";
fun randomize(x: int): void
    asm "ADDRAND";
fun randomizeLt(): void
    asm "LTIME" "ADDRAND";

@pure
fun storeCoins(b: builder, x: int): builder
    asm "STVARUINT16";
@pure
fun slice.loadCoins(mutate self): int
    asm( -> 1 0) "LDVARUINT16";

@pure
fun equalSlices(a: slice, b: slice): int
    asm "SDEQ";
@pure
fun isBuilderNull(b: builder): int
    asm "ISNULL";
@pure
fun storeBuilder(to: builder, from: builder): builder
    asm "STBR";
