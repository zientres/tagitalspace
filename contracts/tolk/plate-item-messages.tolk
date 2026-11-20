struct (0x00000000) PlateItemBid {
    queryId: uint64
    bidAmount: coins
}

struct (0x54531001) SettlePlateAuction {
    queryId: uint64
}

struct (0x54531002) PlateItemOutbid {
    queryId: uint64
}

struct (0x54531003) PlateItemExcesses {
    queryId: uint64
}

struct (0x54531005) RenewPlateOwnership {
    queryId: uint64
}

struct (0x54531007) RetryPlateItemPayout {
    queryId: uint64
}

// The full amount is included so RichBounce can restore the exact liability.
struct (0x54531008) PlateItemRevenuePayout {
    queryId: uint64
    amount: coins
}

// Bounced outbid refunds and refund claims are accounted per original bidder.
struct (0x54531009) PlateItemBidRefund {
    queryId: uint64
    recipient: address
    amount: coins
}

struct (0x5453100A) ClaimPlateItemRefund {
    queryId: uint64
}

struct (0x5fcc3d15) TransferPlateOwnership {
    queryId: uint64
    newOwnerAddress: address
}

struct (0x2fcb26a2) GetNftStaticData {
    queryId: uint64
}

struct (0x8b771735) ReportNftStaticData {
    queryId: uint64
    index: uint256
    collectionAddress: address
}
