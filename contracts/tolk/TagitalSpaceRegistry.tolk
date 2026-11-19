import "registry-state"
import "registry-messages"
import "registry-storage"
import "registry-request"
import "plate-item-state"
import "plate-identity"
import "russia-regions"\nimport "plate-item-messages"

contract TagitalSpaceRegistry {
    author: "TagitalSpace"
    version: "0.2.0"
    description: "TagitalSpace Russia plate collection; each plate has its own auction contract"
    incomingMessages: AllowedRegistryMessage
    storage: TagitalSpaceRegistryStorage
}

type AllowedRegistryMessage = StartPlateAuction | RegistryTreasuryDeposit | RequestRegistryTreasuryPayout

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

        RequestRegistryTreasuryPayout => {
            val storage = TagitalSpaceRegistryStorage.load();
            val itemAddress = calcDeployedPlateItem(
                msg.identityKey,
                storage.nftItemCode,
            );
            val claim = createMessage({
                bounce: BounceMode.NoBounce,
                dest: itemAddress,
                value: 0,
                body: ClaimPlatePayout {
                    queryId: msg.queryId,
                    beneficiaryKind: 1,
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

get fun get_registry_treasury_balance(): coins {
    return TagitalSpaceRegistryStorage.load().treasuryBalance;
}
