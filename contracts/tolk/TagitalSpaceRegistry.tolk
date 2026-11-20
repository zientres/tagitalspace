import "plate-identity"
import "plate-item-messages"
import "plate-item-state"
import "registry-messages"
import "registry-refunds"
import "registry-request"
import "registry-state"
import "registry-storage"
import "russia-regions"

contract TagitalSpaceRegistry {
    author: "TagitalSpace"
    version: "0.4.0"
    description: "TagitalSpace Russia plate collection; each plate has its own auction contract"
    incomingMessages: AllowedRegistryMessage
    storage: TagitalSpaceRegistryStorage
}

type AllowedRegistryMessage = StartPlateAuction | ClaimRegistryRefund

// TON DNS collection pattern: validate the requested identity, derive the
// deterministic item StateInit, and deploy that item with its opening bid.
fun onInternalMessage(in: InMessage) {
    // Allow the configured owner to deploy the Registry with an empty body.
    // All later non-empty messages must use the typed messages below.
    if (in.body.isEmpty()) {
        val storage = TagitalSpaceRegistryStorage.load();
        assert (in.senderAddress == storage.ownerAddress) throw 734;
        return;
    }

    val msg = lazy AllowedRegistryMessage.fromSlice(in.body);
    match (msg) {
        StartPlateAuction => {
            var storage = TagitalSpaceRegistryStorage.load();
            val prepared = tagitalSpacePrepareRussiaFirstBid(
                msg.plateBody,
                msg.regionCode,
                msg.queryId,
                in.valueCoins,
            );

            val existingIndex = storage.itemIndexByIdentity.get(prepared.identityKey);
            var nftIndex: uint64 = 0;
            if (existingIndex.isFound) {
                nftIndex = existingIndex.loadValue();
            } else {
                nftIndex = storage.nextItemIndex;
                storage.nextItemIndex += 1;
                storage.itemIndexByIdentity.set(prepared.identityKey, nftIndex);
                storage.identityByItemIndex.set(nftIndex, prepared.identityKey);
                storage.save();
            }

            val deployItem = createMessage({
                bounce: BounceMode.RichBounce,
                dest: calcDeployedPlateItem(prepared.identityKey, storage.nftItemCode),
                value: 0,
                body: PlateItemInitData {
                    firstBidder: in.senderAddress,
                    nftIndex,
                    firstBidAmount: prepared.startingPrice,
                    plateBody: msg.plateBody,
                    regionCode: msg.regionCode,
                    auctionRevenueAddress: storage.auctionRevenueAddress,
                },
            });
            deployItem.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
        }
        ClaimRegistryRefund => {
            var storage = TagitalSpaceRegistryStorage.load();
            tagitalSpaceClaimRegistryRefund(
                in.senderAddress,
                in.valueCoins,
                mutate storage,
                msg.queryId,
            );
        }
    }
}

fun onBouncedMessage(in: InMessageBounced) {
    val rich = lazy RichBounceBody.fromSlice(in.bouncedBody);
    val originalBody = rich.originalBody.beginParse();
    val opcode = originalBody.preloadUint(32);
    var storage = TagitalSpaceRegistryStorage.load();

    if (opcode == 0x54530003) {
        val refund = lazy RegistryRefund.fromSlice(rich.originalBody.beginParse());
        val originalInfo = rich.originalInfo.load();

        assert (in.senderAddress == refund.recipient) throw 743;
        assert (refund.amount > 0) throw 743;
        assert (refund.amount == originalInfo.valueCoins) throw 743;
        assert (in.valueCoins + TAGITALSPACE_REGISTRY_REFUND_FEE_BUFFER >= refund.amount) throw 743;

        // Restore the full claim; the claimant's attached fee buffer covers
        // the bounce cost if the receiving wallet/contract rejects the retry.
        tagitalSpaceRegistryRecordClaimableRefund(
            refund.recipient,
            refund.amount,
            mutate storage,
        );
        storage.save();
        return;
    }

    val init = lazy PlateItemInitData.fromSlice(rich.originalBody.beginParse());
    val originalInfo = rich.originalInfo.load();

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
    val registeredIndex = storage.itemIndexByIdentity.get(prepared.identityKey);
    assert (registeredIndex.isFound) throw 739;
    assert (registeredIndex.loadValue() == init.nftIndex) throw 739;

    val expectedItemAddress = calcDeployedPlateItem(
        prepared.identityKey,
        storage.nftItemCode,
    ).calculateAddress();
    assert (in.senderAddress == expectedItemAddress) throw 739;
    assert (in.valueCoins > 0) throw 739;

    // Keep failed deployment funds in the Registry until the original bidder
    // explicitly claims them. This also handles contract wallets that reject
    // unsolicited refund messages.
    tagitalSpaceRegistryRecordClaimableRefund(
        init.firstBidder,
        in.valueCoins,
        mutate storage,
    );
    storage.save();
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

get fun get_claimable_registry_refund(ownerAddress: address): coins {
    val storage = TagitalSpaceRegistryStorage.load();
    val lookup = storage.claimableRefunds.get(ownerAddress);
    if (!lookup.isFound) {
        return 0;
    }
    return lookup.loadValue();
}

get fun get_claimable_registry_refund_total(): coins {
    return TagitalSpaceRegistryStorage.load().claimableRefundTotal;
}
