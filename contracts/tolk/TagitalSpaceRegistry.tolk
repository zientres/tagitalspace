import "registry-state"
import "registry-messages"
import "registry-storage"
import "registry-request"
import "registry-transitions"

contract TagitalSpaceRegistry {
    author: "TagitalSpace"
    version: "0.1.0"
    description: "TagitalSpace Russia plate registry"
    incomingMessages: AllowedRegistryMessage
    storage: TagitalSpaceRegistryStorage
}

type AllowedRegistryMessage = StartPlateAuction

// The first-bid path is open to every wallet. The reservation is persisted
// before the asynchronous Auction Manager message is emitted.
fun onInternalMessage(in: InMessage) {
    var msg = lazy AllowedRegistryMessage.fromSlice(in.body);

    match (msg) {
        StartPlateAuction => {
            var storage = TagitalSpaceRegistryStorage.load();

            val prepared = tagitalSpacePrepareRussiaFirstBid(
                msg.plateBody,
                msg.regionCode,
                msg.queryId,
                in.senderAddress,
                in.valueCoins,
            );

            val inserted = tagitalSpaceRegistryTryInsertEntry(
                mutate storage,
                prepared.identityKey,
                prepared.pendingEntry,
            );
            assert (inserted) throw 734;

            // Persist the unique reservation before sending to the manager.
            storage.save();

            val createAuction = createMessage({
                bounce: BounceMode.RichBounce,
                dest: storage.auctionManagerAddress,
                value: in.valueCoins,
                body: CreateManagedAuction {
                    queryId: msg.queryId,
                    identityKey: prepared.identityKey,
                    plateBody: msg.plateBody,
                    regionCode: msg.regionCode,
                    initiator: in.senderAddress,
                    firstBid: prepared.startingPrice,
                    collectionOwner: storage.ownerAddress,
                    developmentSecurityFund: storage.developmentSecurityFund,
                },
            });
            // Pay forwarding fees from the Registry reserve so the Manager
            // receives the complete bid amount, not a fee-reduced amount.
            createAuction.send(SEND_MODE_PAY_FEES_SEPARATELY);
        }
    }
}

// A bounced manager-creation message proves that the manager did not accept
// the request. Only the exact pending query may be released and refunded.
fun onBouncedMessage(in: InMessageBounced) {
    val bounced = RichBounceBody.fromSlice(in.bouncedBody);
    val original = CreateManagedAuction.fromCell(bounced.originalBody);

    var storage = TagitalSpaceRegistryStorage.load();
    assert (in.senderAddress == storage.auctionManagerAddress) throw 735;

    val found = storage.entries.get(original.identityKey);
    assert (found.isFound) throw 736;

    val entry = found.loadValue();
    assert (entry.status == TAGITALSPACE_REGISTRY_AUCTION_PENDING) throw 737;
    assert (entry.pendingQueryId == original.queryId) throw 738;
    assert (entry.pendingInitiator != null) throw 739;

    val refundAddress = entry.pendingInitiator!;
    assert (tagitalSpaceRegistryDeleteEntry(mutate storage, original.identityKey)) throw 740;
    storage.save();

    val refund = createMessage({
        bounce: BounceMode.NoBounce,
        dest: refundAddress,
        value: 0,
        body: TagitalSpaceProtocolExcesses {
            queryId: original.queryId,
        },
    });
    refund.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
}
