// TagitalSpace Registry collection storage.
// Every plate item pays 100% of settled auction proceeds to one configured address.
struct TagitalSpaceRegistryStorage {
    ownerAddress: address
    auctionRevenueAddress: address
    nftItemCode: cell
    // Failed Registry deployments remain claimable by their original bidder.
    claimableRefunds: map<address, coins>
    claimableRefundTotal: coins
}
