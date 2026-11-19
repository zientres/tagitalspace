import "registry-state"
import "registry-messages"
import "registry-storage"
import "registry-request"
import "plate-item-state"

contract TagitalSpaceRegistry {
    author: "TagitalSpace"
    version: "0.2.0"
    description: "TagitalSpace Russia plate collection; each plate has its own auction contract"
    incomingMessages: AllowedRegistryMessage
    storage: TagitalSpaceRegistryStorage
}

type AllowedRegistryMessage = StartPlateAuction | RegistryTreasuryDeposit

// TON DNS collection pattern: validate the requested identity, derive the
// deterministic item StateInit, and send the first bid directly to that item.
// Auction state and all later bids are handled by the item contract itself.
fun onInternalMessage(in: InMessage) {
    var msg = lazy AllowedRegistryMessage.fromSlice(in.body);

    match (msg) {
        StartPlateAuction => {
            val storage = TagitalSpaceRegistryStorage.load();
            val prepared = tagitalSpacePrepareRussiaFirstBid(
                msg.plateBody,
                msg.regionCode,
                msg.queryId,
                in.valueCoins,
            );

            val deployItem = createMessage({
                bounce: BounceMode.RichBounce,
                dest: calcDeployedPlateItem(prepared.identityKey, storage.nftItemCode),
                value: 0,
                body: PlateItemInitData {
                    firstBidder: in.senderAddress,
                    plateBody: msg.plateBody,
                    regionCode: msg.regionCode,
                    collectionOwner: storage.ownerAddress,
                    developmentSecurityFund: storage.developmentSecurityFund,
                },
            });
            deployItem.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
        }

        RegistryTreasuryDeposit => {
            var storage = TagitalSpaceRegistryStorage.load();
            val expectedItemAddress = calcDeployedPlateItem(
                msg.identityKey,
                storage.nftItemCode,
            ).calculateAddress();

            assert (in.senderAddress == expectedItemAddress) throw 763;
            storage.treasuryBalance += in.valueCoins;
            storage.save();
        }
    }
}
