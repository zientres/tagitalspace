import "registry-state"

// Persistent Registry storage helpers.
// Registry entries are stored as cells in a uint256-keyed dictionary so the
// full serialized entry can evolve without changing the dictionary value type.

fun TagitalSpaceRegistryStorage.load(): TagitalSpaceRegistryStorage {
    return TagitalSpaceRegistryStorage.fromCell(contract.getData());
}

fun TagitalSpaceRegistryStorage.save(self) {
    contract.setData(self.toCell());
}

fun tagitalSpaceRegistryCreateInitialStorage(
    ownerAddress: address,
    developmentSecurityFund: address,
    auctionManagerAddress: address,
): TagitalSpaceRegistryStorage {
    return TagitalSpaceRegistryStorage {
        ownerAddress,
        developmentSecurityFund,
        auctionManagerAddress,
        treasuryBalance: 0,
        entries: [],
    };
}

// Returns null when the identity has no reservation.
fun tagitalSpaceRegistryGetEntryCell(
    storage: TagitalSpaceRegistryStorage,
    identityKey: uint256,
): cell? {
    val found = storage.entries.get(identityKey);
    if (!found.isFound) {
        return null;
    }
    return found.loadValue();
}

// Add-only insertion is intentional: a concurrent first-bid request must
// never overwrite an existing reservation, including AUCTION_PENDING.
fun tagitalSpaceRegistryTryInsertEntry(
    mutate storage: TagitalSpaceRegistryStorage,
    identityKey: uint256,
    entry: TagitalSpaceRegistryEntry,
): bool {
    return storage.entries.addIfNotExists(identityKey, entry.toCell());
}

fun tagitalSpaceRegistryReplaceEntry(
    mutate storage: TagitalSpaceRegistryStorage,
    identityKey: uint256,
    entry: TagitalSpaceRegistryEntry,
): bool {
    return storage.entries.replaceIfExists(identityKey, entry.toCell());
}

fun tagitalSpaceRegistryDeleteEntry(
    mutate storage: TagitalSpaceRegistryStorage,
    identityKey: uint256,
): bool {
    return storage.entries.delete(identityKey);
}
