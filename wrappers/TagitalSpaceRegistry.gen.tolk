/// Auto-generated-style wrapper for contract 'TagitalSpaceRegistry'

import "../.acton/build"
import "../.acton/emulation/network"
import "../.acton/testing/assert"
import "../contracts/tolk/registry-messages"
import "../contracts/tolk/registry-state"

struct TagitalSpaceRegistry {
    address: address
    stateInit: ContractState? = null
    toShard: AddressShardingOptions? = null
}

fun TagitalSpaceRegistry.fromStorage(
    storage: TagitalSpaceRegistryStorage,
    toShard: AddressShardingOptions? = null,
    workchain: int8 = BASECHAIN,
): TagitalSpaceRegistry {
    val stateInit = ContractState {
        code: build("TagitalSpaceRegistry"),
        data: storage.toCell(),
    };
    val address = AutoDeployAddress { workchain, stateInit, toShard }.calculateAddress();
    return TagitalSpaceRegistry { address, stateInit, toShard };
}

fun TagitalSpaceRegistry.deploy(
    self,
    from: address,
    config: SendParams = {},
): SendResultList {
    if (self.stateInit == null) {
        Assert.fail("Cannot deploy a contract created with 'fromAddress' because it lacks state init for deployment");
    }
    val deployMessage = createMessage({
        bounce: config.bounce,
        value: config.value,
        dest: {
            workchain: self.address.getWorkchain(),
            stateInit: self.stateInit,
            toShard: self.toShard,
        },
    });
    return net.send(from, deployMessage);
}

fun TagitalSpaceRegistry.sendStartPlateAuction(
    self,
    from: address,
    queryId: uint64,
    plateBody: string,
    regionCode: uint16,
    config: SendParams = {},
): SendResultList {
    val startAuctionMessage = createMessage({
        bounce: config.bounce,
        value: config.value,
        dest: self.address,
        body: StartPlateAuction { queryId, plateBody, regionCode },
    });
    return net.send(from, startAuctionMessage);
}

fun TagitalSpaceRegistry.sendClaimRegistryRefund(
    self,
    from: address,
    queryId: uint64,
    config: SendParams = {},
): SendResultList {
    val claimRefundMessage = createMessage({
        bounce: config.bounce,
        value: config.value,
        dest: self.address,
        body: ClaimRegistryRefund { queryId },
    });
    return net.send(from, claimRefundMessage);
}

fun TagitalSpaceRegistry.getPlateItemAddress(
    self,
    plateBody: string,
    regionCode: uint16,
): address {
    return net.runGetMethod(self.address, "get_plate_item_address", [plateBody, regionCode]);
}

fun TagitalSpaceRegistry.getAuctionRevenueAddress(self): address {
    return net.runGetMethod(self.address, "get_auction_revenue_address");
}

fun TagitalSpaceRegistry.getPlateStartingPrice(
    self,
    plateBody: string,
): coins {
    return net.runGetMethod(self.address, "get_plate_starting_price", [plateBody]);
}

fun TagitalSpaceRegistry.getCollectionData(
    self,
): (int, cell, address) {
    return net.runGetMethod(self.address, "get_collection_data");
}

fun TagitalSpaceRegistry.getNftAddressByIndex(
    self,
    index: int,
): address {
    return net.runGetMethod(self.address, "get_nft_address_by_index", [index]);
}

fun TagitalSpaceRegistry.getNftContent(
    self,
    index: int,
    individualContent: cell,
): cell {
    return net.runGetMethod(self.address, "get_nft_content", [index, individualContent]);
}

fun TagitalSpaceRegistry.getClaimableRefund(
    self,
    ownerAddress: address,
): coins {
    return net.runGetMethod(self.address, "get_claimable_registry_refund", [ownerAddress]);
}

fun TagitalSpaceRegistry.getClaimableRefundTotal(self): coins {
    return net.runGetMethod(self.address, "get_claimable_registry_refund_total");
}
