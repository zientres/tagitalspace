import "registry-state"
import "registry-messages"
import "registry-storage"
import "registry-request"
import "plate-identity"
import "plate-pricing"

contract TagitalSpaceRegistry {
    author: "TagitalSpace"
    version: "0.2.0"
    description: "TagitalSpace Russia plate collection; each plate has its own auction contract"
    incomingMessages: AllowedRegistryMessage
    storage: TagitalSpaceRegistryStorage
}

type AllowedRegistryMessage =
    | StartPlateAuction
    | RegistryTreasuryDeposit
    | WithdrawRegistryTreasury

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

            val itemInitialStorage = PlateItemStorageNotInitialized {
                identityKey: prepared.identityKey,
                collectionAddress: contract.getAddress(),
            };
            val itemAddress = {
                workchain: BASECHAIN,
                stateInit: {
                    code: storage.nftItemCode,
                    data: itemInitialStorage.toCell(),
                },
            };

            val deployItem = createMessage({
                bounce: BounceMode.RichBounce,
                dest: itemAddress,
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
            storage.treasuryBalance += in.valueCoins;
            storage.save();
        }

        WithdrawRegistryTreasury => {
            var storage = TagitalSpaceRegistryStorage.load();
            assert (in.senderAddress == storage.ownerAddress) throw 760;
            assert (msg.amount > 0 && msg.amount <= storage.treasuryBalance) throw 761;
            assert (msg.destination.getWorkchain() == BASECHAIN) throw 762;

            storage.treasuryBalance -= msg.amount;
            storage.save();

            val payout = createMessage({
                bounce: true,
                dest: msg.destination,
                value: msg.amount,
                body: RegistryTreasuryDeposit { queryId: msg.queryId },
            });
            payout.send(SEND_MODE_PAY_FEES_SEPARATELY);
        }
    }
}
