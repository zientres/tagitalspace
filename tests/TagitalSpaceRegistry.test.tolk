import "@stdlib/gas-payments"
import "../.acton/build"
import "../.acton/emulation/network"
import "../.acton/emulation/testing"
import "../.acton/testing/expect"
import "../wrappers/TagitalSpaceRegistry.gen"
import "../contracts/tolk/registry-state"

fun deployTestRegistry(
    owner: Treasury,
    revenue: Treasury,
    itemCode: cell,
): TagitalSpaceRegistry {
    val registry = TagitalSpaceRegistry.fromStorage({
        ownerAddress: owner.address,
        auctionRevenueAddress: revenue.address,
        nftItemCode: itemCode,
    });
    val deployed = registry.deploy(owner.address, { value: grams("0.2") });
    expect(deployed).toHaveSuccessfulDeploy({ to: registry.address });
    return registry;
}

get fun `test bounced Registry item deployment refunds the first bidder`() {
    val owner = testing.treasury("registry-owner");
    val bidder = testing.treasury("registry-bidder");
    val revenue = testing.treasury("registry-revenue");

    // Registry bytecode is deliberately used as the item code. It rejects the
    // PlateItemInitData opcode, causing a genuine TVM RichBounce.
    val registry = deployTestRegistry(owner, revenue, build("TagitalSpaceRegistry"));

    val result = registry.sendStartPlateAuction(
        bidder.address,
        1,
        beginCell().storeUint(0x413132334243, 48).endCell(),
        77,
        { value: grams("3.2") },
    );

    expect(result).toHaveSuccessfulTx({ to: registry.address });
    expect(result).toHaveTx({ to: bidder.address });
}

get fun `test Registry deploys an item and rejects duplicate first-bid requests`() {
    val owner = testing.treasury("registry-success-owner");
    val firstBidder = testing.treasury("registry-success-first-bidder");
    val secondBidder = testing.treasury("registry-success-second-bidder");
    val revenue = testing.treasury("registry-success-revenue");
    val registry = deployTestRegistry(owner, revenue, build("TagitalSpacePlateItem"));
    val plateBody = beginCell().storeUint(0x413132334243, 48).endCell();

    val firstRequest = registry.sendStartPlateAuction(
        firstBidder.address,
        2,
        plateBody,
        77,
        { value: grams("3.2") },
    );

    val itemAddress = registry.getPlateItemAddress(plateBody, 77);
    val item = TagitalSpacePlateItem.fromAddress(itemAddress);
    expect(firstRequest).toHaveSuccessfulDeploy({ to: itemAddress });

    val auctionBeforeDuplicate = item.getAuctionInfo()!;
    expect(auctionBeforeDuplicate.highestBid).toEqual(grams("3"));
    expect(auctionBeforeDuplicate.highestBidder).toEqual(firstBidder.address);

    val duplicateRequest = registry.sendStartPlateAuction(
        secondBidder.address,
        3,
        plateBody,
        77,
        { value: grams("3.2") },
    );

    expect(duplicateRequest).toHaveTx({ to: secondBidder.address });
    val auctionAfterDuplicate = item.getAuctionInfo()!;
    expect(auctionAfterDuplicate.highestBid).toEqual(grams("3"));
    expect(auctionAfterDuplicate.highestBidder).toEqual(firstBidder.address);
}

