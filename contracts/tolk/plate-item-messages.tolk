import "registry-messages"

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

struct (0x5fcc3d15) TransferPlateOwnership {
    queryId: uint64
    newOwnerAddress: address
}
