import "@stdlib/gas-payments"
import "../.acton/build"
import "../.acton/emulation/network"
import "../.acton/emulation/testing"
import "../.acton/testing/expect"
import "../wrappers/TagitalSpaceRegistry.gen"
import "../wrappers/TagitalSpacePlateItem.gen"
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
        claimableRefunds: [],
        claimableRefundTotal: 0,
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
    val claimable = registry.getClaimableRefund(bidder.address);
    expect(claimable > 0).toEqual(true);
    expect(registry.getClaimableRefundTotal()).toEqual(claimable);

    val claim = registry.sendClaimRegistryRefund(
        bidder.address,
        2,
        { value: grams("0.1") },
    );
    expect(claim).toHaveSuccessfulTx({ to: registry.address });
    expect(claim).toHaveTx({ to: bidder.address, value: claimable });
    expect(registry.getClaimableRefund(bidder.address)).toEqual(0);
    expect(registry.getClaimableRefundTotal()).toEqual(0);
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

    expect(duplicateRequest).toHaveSuccessfulTx({ to: itemAddress });
    expect(item.getClaimableRefund(secondBidder.address) > 0).toEqual(true);
    val auctionAfterDuplicate = item.getAuctionInfo()!;
    expect(auctionAfterDuplicate.highestBid).toEqual(grams("3"));
    expect(auctionAfterDuplicate.highestBidder).toEqual(firstBidder.address);
}

get fun `test Registry rejects invalid plate and unsupported region`() {
    val owner = testing.treasury("registry-validation-owner");
    val bidder = testing.treasury("registry-validation-bidder");
    val revenue = testing.treasury("registry-validation-revenue");
    val registry = deployTestRegistry(owner, revenue, build("TagitalSpacePlateItem"));

    val invalidPlate = registry.sendStartPlateAuction(
        bidder.address,
        4,
        beginCell().storeUint(0x493132334243, 48).endCell(),
        77,
        { value: grams("3.2") },
    );
    expect(invalidPlate).toHaveFailedTx({
        to: registry.address,
        exitCode: 730,
    });

    val unsupportedRegion = registry.sendStartPlateAuction(
        bidder.address,
        5,
        beginCell().storeUint(0x413132334243, 48).endCell(),
        20,
        { value: grams("3.2") },
    );
    expect(unsupportedRegion).toHaveFailedTx({
        to: registry.address,
        exitCode: 731,
    });
}

get fun `test Registry derives different item addresses for different regions`() {
    val owner = testing.treasury("registry-address-owner");
    val revenue = testing.treasury("registry-address-revenue");
    val registry = deployTestRegistry(owner, revenue, build("TagitalSpacePlateItem"));
    val plateBody = beginCell().storeUint(0x413132334243, 48).endCell();

    val region77Address = registry.getPlateItemAddress(plateBody, 77);
    val region78Address = registry.getPlateItemAddress(plateBody, 78);
    expect(region77Address == region78Address).toEqual(false);
    expect(registry.getAuctionRevenueAddress()).toEqual(revenue.address);
}

get fun `test Registry rejects empty-body messages from non-owner`() {
    val owner = testing.treasury("registry-empty-owner");
    val attacker = testing.treasury("registry-empty-attacker");
    val revenue = testing.treasury("registry-empty-revenue");
    val registry = deployTestRegistry(owner, revenue, build("TagitalSpacePlateItem"));

    val unauthorizedDeploy = createMessage({
        bounce: false,
        value: grams("0.05"),
        dest: registry.address,
    });
    val result = net.send(attacker.address, unauthorizedDeploy);

    expect(result).toHaveFailedTx({
        to: registry.address,
        exitCode: 734,
    });
}

get fun `test Registry restores a refund when the bidder claim bounces`() {
    val owner = testing.treasury("registry-retry-owner");
    val bidder = randomAddress("registry-retry-unavailable-bidder");
    val revenue = testing.treasury("registry-retry-revenue");
    val registry = deployTestRegistry(owner, revenue, build("TagitalSpaceRegistry"));

    val request = registry.sendStartPlateAuction(
        bidder,
        6,
        beginCell().storeUint(0x413132334243, 48).endCell(),
        77,
        { value: grams("3.2") },
    );
    expect(request).toHaveSuccessfulTx({ to: registry.address });

    val originalClaim = registry.getClaimableRefund(bidder);
    expect(originalClaim > 0).toEqual(true);

    val failedClaim = registry.sendClaimRegistryRefund(
        bidder,
        7,
        { value: grams("0.1") },
    );
    expect(failedClaim).toHaveSuccessfulTx({ to: registry.address });
    expect(registry.getClaimableRefund(bidder)).toEqual(originalClaim);
    expect(registry.getClaimableRefundTotal()).toEqual(originalClaim);
}

