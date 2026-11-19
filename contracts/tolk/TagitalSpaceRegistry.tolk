import "registry-state"
import "registry-messages"
import "registry-storage"
import "registry-request"
import "plate-item-state"
import "plate-identity"
import "russia-regions"
import "plate-item-messages"

contract TagitalSpaceRegistry {
    author: "TagitalSpace"
    version: "0.3.0"
    description: "TagitalSpace Russia plate collection; each plate has its own auction contract"
    incomingMessages: AllowedRegistryMessage
    storage: TagitalSpaceRegistryStorage
}

type AllowedRegistryMessage = StartPlateAuction | RequestAuctionRevenuePayout

// TON DNS collection pattern: validate the requested identity, derive the
// deterministic item StateInit, and send the first bid directly to that item.
fun onInternalMessage(in: InMessage) {
    var msg = lazy AllowedRegistryMessage.fromSlice(in.body);
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
                    collectionOwner: storage.ownerAddress,
                    auctionRevenueAddress: storage.auctionRevenueAddress,
                },
            });
            deployItem.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
        }
        // Anyone may trigger a claim. The item always pays its fixed configured
        // address; the caller cannot redirect or withdraw auction proceeds.
        RequestAuctionRevenuePayout => {
            val storage = TagitalSpaceRegistryStorage.load();
            val itemAddress = calcDeployedPlateItem(msg.identityKey, storage.nftItemCode);
            val claim = createMessage({
                bounce: BounceMode.NoBounce,
                dest: itemAddress,
                value: 0,
                body: ClaimPlatePayout {
                    queryId: msg.queryId,
                    beneficiaryKind: 2,
                },
            });
            claim.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
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
