// TagitalSpace Registry collection storage.
// Auctions live in deterministic per-plate item contracts, as in TON DNS.

struct TagitalSpaceRegistryStorage {
    ownerAddress: address
    developmentSecurityFund: address
    nftItemCode: cell
    treasuryBalance: coins
}
