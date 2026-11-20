// Registry -> per-plate item protocol.
// Each plate item owns its auction state and pays proceeds to the fixed recipient.
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
    auctionRevenueAddress: address
}

struct (0x54530002) ClaimRegistryRefund {
    queryId: uint64
}

struct (0x54530003) RegistryRefund {
    queryId: uint64
    recipient: address
    amount: coins
}
