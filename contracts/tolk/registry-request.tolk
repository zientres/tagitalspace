import "plate-identity"
import "plate-pricing"
import "russia-regions"

// Validates the first bid request and returns its deterministic item identity.
struct TagitalSpacePreparedAuctionRequest {
    identityKey: uint256
    startingPrice: coins
}

fun tagitalSpacePrepareRussiaFirstBid(
    plateBody: cell,
    regionCode: uint16,
    queryId: uint64,
    attachedValue: coins,
): TagitalSpacePreparedAuctionRequest {
    val plate = plateBody.beginParse();

    assert (tagitalSpaceValidatePlateBody(plate)) throw 730;
    assert (tagitalSpaceValidateRussiaRegionCode(regionCode as int)) throw 731;
    assert (queryId != 0) throw 732;

    val startingPrice = tagitalSpacePlateStartPrice(plate);
    assert (attachedValue >= startingPrice) throw 733;

    val identityCell = tagitalSpaceBuildPlateIdentity(plate, regionCode as int);
    return {
        identityKey: identityCell.hash(),
        startingPrice,
    };
}
