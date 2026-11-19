import "registry-messages"

struct PlateItemStorageNotInitialized {
    identityKey: uint256
    collectionAddress: address
}

struct PlateAuctionState {
    highestBidder: address
    highestBid: coins
    auctionEndTime: uint64
}

struct PlateItemStorageInitialized {
    identityKey: uint256
    collectionAddress: address
    plateBody: cell
    regionCode: uint16
    collectionOwner: address
    developmentSecurityFund: address
    ownerAddress: address?
    auction: Cell<PlateAuctionState>?
    pendingOwnerPayout: coins
    pendingTreasuryPayout: coins
    pendingSecurityPayout: coins
}

fun PlateItemStorageInitialized.save(self) {
    contract.setData(self.toCell());
}

fun PlateItemStorageInitialized.unpackAuction(self): (bool, PlateAuctionState) {
    if (self.auction == null) {
        return (true, {
            highestBidder: contract.getAddress(),
            highestBid: 0,
            auctionEndTime: 0,
        });
    }
    return (false, self.auction.load());
}

struct PlateItemNftData {
    initialized: bool
    identityKey: uint256
    collectionAddress: address
    ownerAddress: address?
    plateBody: cell?
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
    return {
        workchain: BASECHAIN,
        stateInit: {
            code: itemCode,
            data: itemStorage.toCell(),
        },
    };
}
