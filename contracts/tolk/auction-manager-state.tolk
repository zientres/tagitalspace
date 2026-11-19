// TagitalSpace Auction Manager storage model.
// This file defines the accounting/state layout only. Message handlers,
// claim flows, and bounce recovery are implemented in the manager contract.

const TAGITALSPACE_AUCTION_STATUS_ACTIVE = 1;
const TAGITALSPACE_AUCTION_STATUS_SETTLED = 2;
const TAGITALSPACE_AUCTION_STATUS_CANCELLED = 3;

struct TagitalSpaceManagedAuction {
    identityKey: uint256
    plateBody: cell
    regionCode: uint16
    status: uint8
    highestBidder: address?
    highestBid: coins
    endTime: uint64
    collectionOwner: address
    developmentSecurityFund: address
    settlementQueryId: uint64
}

// All credit maps are keyed by a deterministic hash of the beneficiary
// address. Each value cell must retain the full address alongside its amount
// so a lookup can verify the key and avoid treating a hash as authorization.
struct TagitalSpaceAuctionManagerStorage {
    ownerAddress: address
    registryAddress: address
    treasuryBalance: coins
    totalActiveBidEscrow: coins
    totalRefundLiability: coins
    totalOwnerPayoutLiability: coins
    totalSecurityPayoutLiability: coins
    auctions: map<uint256, cell>
    refundCredits: map<uint256, cell>
    ownerPayoutCredits: map<uint256, cell>
    securityPayoutCredits: map<uint256, cell>
}
