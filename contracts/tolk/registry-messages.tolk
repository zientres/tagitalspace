// Registry -> per-plate item protocol.
// Each plate item owns its auction state; Registry only deploys deterministic items.

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
    developmentSecurityFund: address
}

struct (0x54530002) RegistryTreasuryDeposit {
    queryId: uint64
    identityKey: uint256
}

struct (0x54530003) RequestRegistryTreasuryPayout {
    queryId: uint64
    identityKey: uint256
}
