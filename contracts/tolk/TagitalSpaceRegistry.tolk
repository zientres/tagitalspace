import "registry-state"
import "registry-messages"
import "registry-storage"
import "registry-request"
import "plate-item-state"
import "plate-identity"
import "russia-regions"

contract TagitalSpaceRegistry {
    author: "TagitalSpace"
    version: "0.4.0"
    description: "TagitalSpace Russia plate collection; each plate has its own auction contract"
    incomingMessages: StartPlateAuction
    storage: TagitalSpaceRegistryStorage
}

// TON DNS collection pattern: validate the requested identity, derive the
// deterministic item StateInit, and deploy that item with its opening bid.
fun onInternalMessage(in: InMessage) {
    val msg = lazy StartPlateAuction.fromSlice(in.body);
    match (msg) {
        StartPlateAuction => {
            val storage = TagitalSpaceRegistryStorage.load();
            val prepared = tagitalSpacePrepareRussiaFirstBid(
                msg.plateBody, msg.regionCode, msg.queryId, in.valueCoins,
            );
            val deployItem = createMessage({
                bounce: BounceMode.RichBounce,
                dest: calcDeployedPlateItem(prepared.identityKey, storage.nftItemCode),
                value: 0,
                body: PlateItemInitData {
                    firstBidder: in.senderAddress,
                    firstBidAmount: prepared.startingPrice,
                    plateBody: msg.plateBody,
                    regionCode: msg.regionCode,
                    auctionRevenueAddress: storage.auctionRevenueAddress,
                },
            });
            deployItem.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
        }
    }
}

get fun get_plate_item_address(plateBody: cell, regionCode: uint16): address {
    val storage = TagitalSpaceRegistryStorage.load();
    val plate = plateBody.beginParse();
    assert (tagitalSpaceValidatePlateBody(plate)) throw 730;
    assert (tagitalSpaceValidateRussiaRegionCode(regionCode as int)) throw 731;
    val identityKey = tagitalSpaceBuildPlateIdentity(plate, regionCode as int).hash();
    return calcDeployedPlateItem(identityKey, storage.nftItemCode).calculateAddress();
}

get fun get_auction_revenue_address(): address {
    return TagitalSpaceRegistryStorage.load().auctionRevenueAddress;
}
