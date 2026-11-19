import "registry-state"

fun TagitalSpaceRegistryStorage.load(): TagitalSpaceRegistryStorage {
    return TagitalSpaceRegistryStorage.fromCell(contract.getData());
}

fun TagitalSpaceRegistryStorage.save(self) {
    contract.setData(self.toCell());
}

fun tagitalSpaceRegistryCreateInitialStorage(
    ownerAddress: address,
    developmentSecurityFund: address,
    nftItemCode: cell,
): TagitalSpaceRegistryStorage {
    return TagitalSpaceRegistryStorage {
        ownerAddress,
        developmentSecurityFund,
        nftItemCode,
        treasuryBalance: 0,
    };
}
