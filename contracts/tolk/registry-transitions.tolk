import "registry-state"

// Pure state-transition helpers. Contract message handlers must persist the
// returned entry atomically before sending subsequent outbound messages.

fun tagitalSpaceCreatePendingAuctionEntry(
    plateBody: cell,
    regionCode: uint16,
    queryId: uint64,
    initiator: address,
): TagitalSpaceRegistryEntry {
    assert (queryId != 0) throw 712;

    return TagitalSpaceRegistryEntry {
        plateBody,
        regionCode,
        status: TAGITALSPACE_REGISTRY_AUCTION_PENDING,
        auctionId: 0,
        auctionAddress: null,
        highestBidder: null,
        highestBid: 0,
        auctionEndTime: 0,
        nftItemAddress: null,
        ownerAddress: null,
        expiresAt: 0,
        pendingQueryId: queryId,
        pendingInitiator: initiator,
    };
}

// The callback may activate only the exact reservation created for it.
// The caller must additionally authenticate the sender as the configured
// Auction Manager before invoking this transition.
fun tagitalSpaceActivatePendingAuction(
    entry: TagitalSpaceRegistryEntry,
    queryId: uint64,
    auctionId: uint256,
    auctionAddress: address,
    highestBidder: address,
    highestBid: coins,
    auctionEndTime: uint64,
): TagitalSpaceRegistryEntry {
    assert (entry.status == TAGITALSPACE_REGISTRY_AUCTION_PENDING) throw 713;
    assert (queryId != 0 && entry.pendingQueryId == queryId) throw 714;
    assert (auctionId != 0) throw 715;
    assert (highestBid > 0) throw 716;
    assert (auctionEndTime > blockchain.now()) throw 717;

    return TagitalSpaceRegistryEntry {
        plateBody: entry.plateBody,
        regionCode: entry.regionCode,
        status: TAGITALSPACE_REGISTRY_AUCTION,
        auctionId,
        auctionAddress,
        highestBidder,
        highestBid,
        auctionEndTime,
        nftItemAddress: null,
        ownerAddress: null,
        expiresAt: 0,
        pendingQueryId: 0,
        pendingInitiator: null,
    };
}

// A rejection is eligible to release a reservation only when it refers to
// the exact pending query. The contract handler must authenticate the sender
// before clearing the map entry; this helper deliberately does not delete it.
fun tagitalSpaceCanReleaseRejectedAuction(
    entry: TagitalSpaceRegistryEntry,
    queryId: uint64,
): bool {
    return entry.status == TAGITALSPACE_REGISTRY_AUCTION_PENDING
        && queryId != 0
        && entry.pendingQueryId == queryId;
}
