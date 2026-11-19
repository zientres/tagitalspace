// TagitalSpace Registry <-> Auction Manager message protocol.
// Protocol definitions only: handlers, authentication, value checks and
// bounce recovery must be implemented before deployment.

// User -> Registry: request a first-bid auction for an available plate.
// The canonical six-byte ASCII plate is stored in plateBody.
struct (0x54530001) StartPlateAuction {
    queryId: uint64
    plateBody: cell
    regionCode: uint16
}

// Registry -> Auction Manager: create the auction after the Registry has
// reserved the identity. The attached TON value carries the first bid.
struct (0x54530002) CreateManagedAuction {
    queryId: uint64
    identityKey: uint256
    plateBody: cell
    regionCode: uint16
    initiator: address
    firstBid: coins
    collectionOwner: address
    developmentSecurityFund: address
}

// Auction Manager -> Registry: auction creation accepted.
// Registry must verify sender == configured Auction Manager and match
// queryId + identityKey against the pending reservation.
struct (0x54530003) ManagedAuctionCreated {
    queryId: uint64
    identityKey: uint256
    auctionId: uint256
    auctionAddress: address
    highestBidder: address
    highestBid: coins
    endTime: uint64
}

// Auction Manager -> Registry: creation rejected before auction activation.
// Registry may release the reservation only after authenticating and
// matching this response to the pending query.
struct (0x54530004) ManagedAuctionRejected {
    queryId: uint64
    identityKey: uint256
    errorCode: uint32
}

// Auction Manager -> Registry: auction has been settled exactly once.
// The Registry must authenticate the manager and verify the active auction.
struct (0x54530005) ManagedAuctionSettled {
    queryId: uint64
    identityKey: uint256
    auctionId: uint256
    winner: address
    winningBid: coins
}

// Registry -> NFT item: initialize the item for the winning owner.
// The NFT item must authenticate the Registry as its collection authority.
struct (0x54530006) InitializePlateNft {
    queryId: uint64
    identityKey: uint256
    plateBody: cell
    regionCode: uint16
    ownerAddress: address
    expiresAt: uint64
}

// NFT item -> Registry: initialization succeeded.
// Registry must authenticate the deterministic item address and match queryId.
struct (0x54530007) PlateNftInitialized {
    queryId: uint64
    identityKey: uint256
    nftItemAddress: address
    ownerAddress: address
    expiresAt: uint64
}

// NFT item -> Registry: initialization failed or was rejected.
// Failure handling must preserve the reservation and allow a safe retry.
struct (0x54530008) PlateNftInitializationFailed {
    queryId: uint64
    identityKey: uint256
    errorCode: uint32
}

// Registry -> Auction Manager: ask for cancellation only through an
// explicitly authorized recovery path. Never infer cancellation from timeout.
struct (0x54530009) CancelManagedAuction {
    queryId: uint64
    identityKey: uint256
    auctionId: uint256
}

// Generic query response for idempotent message workflows.
struct (0x5453000A) TagitalSpaceProtocolExcesses {
    queryId: uint64
}
