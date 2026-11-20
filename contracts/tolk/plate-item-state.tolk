struct PlateItemStorageNotInitialized {
    identityKey: uint256
    collectionAddress: address
}

struct PlateAuctionState {
    highestBidder: address
    highestBid: coins
    auctionEndTime: uint64
}

// Immutable identity and payout configuration live in a separate cell.
// This keeps the mutable item root comfortably below TON's 1023-bit limit.
struct PlateItemImmutableData {
    identityKey: uint256
    nftIndex: uint64
    collectionAddress: address
    plateBody: string
    regionCode: uint16
    auctionRevenueAddress: address
}

struct PlateItemStorageInitialized {
    immutable: Cell<PlateItemImmutableData>
    ownerAddress: address?
    lastRenewalTime: uint64
    auction: Cell<PlateAuctionState>?
    // Winning revenue whose previous transfer bounced and must be retried.
    claimablePayout: coins
    // Outbid refunds that bounced, indexed by the original bidder.
    claimableRefunds: map<address, coins>
    // Aggregate liability used to protect every bidder's pending refund.
    claimableRefundTotal: coins
}

fun PlateItemStorageInitialized.save(self) {
    contract.setData(self.toCell());
}

fun PlateItemStorageInitialized.unpackAuction(self): (bool, PlateAuctionState) {
    if (self.auction == null) {
        return (
            true,
            {
                highestBidder: contract.getAddress(),
                highestBid: 0,
                auctionEndTime: 0,
            },
        );
    }
    return (false, self.auction.load());
}

struct PlateItemNftData {
    initialized: bool
    identityKey: uint256
    collectionAddress: address
    ownerAddress: address?
    plateBody: string?
    regionCode: uint16
}

struct PlateItemLoadingStorage {
    data: slice
}

fun startLoadingPlateItemStorage(): PlateItemLoadingStorage {
    return { data: contract.getData().beginParse() };
}

fun PlateItemLoadingStorage.isInitialized(self): bool {
    return self.data.remainingRefsCount() > 0;
}

fun PlateItemLoadingStorage.parseNotInitialized(self): PlateItemStorageNotInitialized {
    return PlateItemStorageNotInitialized.fromSlice(self.data);
}

fun PlateItemLoadingStorage.parseInitialized(self): PlateItemStorageInitialized {
    return PlateItemStorageInitialized.fromSlice(self.data);
}

fun calcDeployedPlateItem(
    identityKey: uint256,
    itemCode: cell,
): AutoDeployAddress {
    val itemStorage = PlateItemStorageNotInitialized {
        identityKey,
        collectionAddress: contract.getAddress(),
    };
    return { workchain: BASECHAIN, stateInit: { code: itemCode, data: itemStorage.toCell() } };
}
