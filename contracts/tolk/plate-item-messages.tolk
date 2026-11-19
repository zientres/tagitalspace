import "registry-messages"

struct (0x00000000) PlateItemBid {
    queryId: uint64
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
