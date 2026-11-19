// TagitalSpace registry storage model.
// This file defines the persisted state layout only; message handlers and
// state-transition functions are implemented separately.

const TAGITALSPACE_REGISTRY_AUCTION = 1;
const TAGITALSPACE_REGISTRY_MINT_PENDING = 2;
const TAGITALSPACE_REGISTRY_OWNED = 3;
const TAGITALSPACE_REGISTRY_RENEWAL_PENDING = 4;
const TAGITALSPACE_REGISTRY_AUCTION_PENDING = 5;

// One map entry is keyed by the hash of the canonical plate+region identity.
// plateBody stores the six canonical ASCII bytes so the key can be checked
// against the full identity when loading an entry.
struct TagitalSpaceRegistryEntry {
    plateBody: cell
    regionCode: uint16
    // One of the status constants above; AUCTION_PENDING closes the async race.
    status: uint8
    auctionId: uint256
    auctionAddress: address?
    highestBidder: address?
    highestBid: coins
    auctionEndTime: uint64
    nftItemAddress: address?
    ownerAddress: address?
    expiresAt: uint64
    pendingQueryId: uint64
}

// Registry-level configuration and accounting.
// Auction bid escrow/refund liabilities belong to the Auction Manager and
// must not be mixed with the registry's retained treasury accounting.
struct TagitalSpaceRegistryStorage {
    ownerAddress: address
    developmentSecurityFund: address
    treasuryBalance: coins
    entries: map<uint256, cell>
}
