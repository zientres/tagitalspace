// Registry -> per-plate item protocol.
// Each plate item owns its auction state; Registry deploys items and forwards revenue claims.
struct (0x54530001) StartPlateAuction {
    queryId: uint64
    plateBody: cell
    regionCode: uint16
}
struct (0x54531006) PlateItemInitData {
    firstBidder: address
    firstBidAmount: coins
    plateBody: cell
    regionCode: uint16
    collectionOwner: address
    auctionRevenueAddress: address
}
struct (0x54530003) RequestAuctionRevenuePayout {
    queryId: uint64
    identityKey: uint256
}
