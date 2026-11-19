import "plate-identity"
import "plate-pricing"
import "russia-regions"
import "registry-transitions"

// Pure validation/preparation only. The handler must persist the pending
// reservation before sending the first-bid request to Auction Manager.
struct TagitalSpacePreparedAuctionRequest {
    identityKey: uint256
    startingPrice: coins
    initiator: address
    pendingEntry: TagitalSpaceRegistryEntry
}

fun tagitalSpacePrepareRussiaFirstBid(
    plateBody: cell,
    regionCode: uint16,
    queryId: uint64,
    initiator: address,
    attachedValue: coins,
): TagitalSpacePreparedAuctionRequest {
    val plate = plateBody.beginParse();

    assert (tagitalSpaceValidatePlateBody(plate)) throw 730;
    assert (tagitalSpaceValidateRussiaRegionCode(regionCode as int)) throw 731;
    assert (queryId != 0) throw 732;

    val startingPrice = tagitalSpacePlateStartPrice(plate);
    assert (tagitalSpaceValidateFirstBid(attachedValue, startingPrice)) throw 733;

    val identityCell = tagitalSpaceBuildPlateIdentity(plate, regionCode as int);
    val identityKey = identityCell.hash();

    return TagitalSpacePreparedAuctionRequest {
        identityKey,
        startingPrice,
        initiator,
        pendingEntry: tagitalSpaceCreatePendingAuctionEntry(
            plateBody,
            regionCode,
            queryId,
        ),
    };
}
