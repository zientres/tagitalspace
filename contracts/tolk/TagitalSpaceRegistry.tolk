import "registry-state"
import "registry-messages"
import "plate-item-messages"
import "registry-storage"
import "registry-request"
import "plate-item-state"
import "plate-identity"
import "russia-regions"

contract TagitalSpaceRegistry {
    author: "TagitalSpace"
    version: "0.4.0"
    description: "TagitalSpace Russia plate collection; each plate has its own auction contract"
    incomingMessages: AllowedRegistryMessage
    storage: TagitalSpaceRegistryStorage
}

type AllowedRegistryMessage = StartPlateAuction

// TON DNS collection pattern: validate the requested identity, derive the
// deterministic item StateInit, and deploy that item with its opening bid.
fun onInternalMessage(in: InMessage) {
    // Allow the configured owner to deploy the Registry with an empty body.
    // All later non-empty messages must use the typed auction request below.
    if (in.body.isEmpty()) {
        val storage = TagitalSpaceRegistryStorage.load();
        assert (in.senderAddress == storage.ownerAddress) throw 734;
        return;
    }

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


fun onBouncedMessage(in: InMessageBounced) {
    val rich = lazy RichBounceBody.fromSlice(in.bouncedBody);
    val init = lazy PlateItemInitData.fromSlice(rich.originalBody.beginParse());
    val originalInfo = rich.originalInfo.load();
    val storage = TagitalSpaceRegistryStorage.load();

    // A Registry deployment bounce must come from the deterministic item
    // address for the exact plate and region encoded in the original init.
    assert (init.auctionRevenueAddress == storage.auctionRevenueAddress) throw 739;
    assert (init.firstBidAmount > 0) throw 739;
    assert (originalInfo.valueCoins >= init.firstBidAmount + 150_000_000) throw 739;

    val prepared = tagitalSpacePrepareRussiaFirstBid(
        init.plateBody,
        init.regionCode,
        1,
        originalInfo.valueCoins,
    );
    assert (prepared.startingPrice == init.firstBidAmount) throw 739;

    val expectedItemAddress = calcDeployedPlateItem(
        prepared.identityKey,
        storage.nftItemCode,
    ).calculateAddress();
    assert (in.senderAddress == expectedItemAddress) throw 739;
    assert (in.valueCoins > 0) throw 739;

    // Return the value that actually bounced (after network fees) to the
    // wallet that initiated this specific first-bid request.
    val refund = createMessage({
        bounce: false,
        dest: init.firstBidder,
        value: 0,
        body: PlateItemExcesses { queryId: blockchain.logicalTime() as uint64 },
    });
    refund.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
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
