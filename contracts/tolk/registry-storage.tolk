import "registry-state"

fun TagitalSpaceRegistryStorage.load(): TagitalSpaceRegistryStorage {
    return TagitalSpaceRegistryStorage.fromCell(contract.getData());
}
fun TagitalSpaceRegistryStorage.save(self) {
    contract.setData(self.toCell());
}
fun tagitalSpaceRegistryCreateInitialStorage(
    ownerAddress: address,
    auctionRevenueAddress: address,
    nftItemCode: cell,
): TagitalSpaceRegistryStorage {
    return TagitalSpaceRegistryStorage {
        ownerAddress,
        auctionRevenueAddress,
        nftItemCode,
    };
}
