import "@stdlib/gas-payments"
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
