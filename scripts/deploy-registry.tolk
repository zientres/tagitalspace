import "@acton/io"
import "@acton/emulation/network"
import "@acton/emulation/scripts"
import "@acton/build"
import "@acton/prompts"
import "@acton/testing/assert"

import "@wrappers/TagitalSpaceRegistry.gen"
import "../contracts/tolk/registry-storage"

const TAGITALSPACE_TESTNET_REVENUE_ADDRESS =
    address("0QAlaQjrvRz8GCm2IJ1QXA6rNGSyyYfH6uNPT0RzKja6VsLi")

fun main() {
    val deployer = scripts.wallet(promptWallet("Select the Registry owner/deployer wallet:"));

    val initialStorage = tagitalSpaceRegistryCreateInitialStorage(
        deployer.address,
        TAGITALSPACE_TESTNET_REVENUE_ADDRESS,
        build("TagitalSpacePlateItem"),
    );
    val registry = TagitalSpaceRegistry.fromStorage(initialStorage);

    println("Deploying TagitalSpace Registry to {}", registry.address);
    println("Owner wallet: {}", deployer.address);
    println("Fixed auction revenue recipient: {}", TAGITALSPACE_TESTNET_REVENUE_ADDRESS);

    val result = registry.deploy(deployer.address, { value: grams("0.2") });
    val trace = result.waitForTrace();
    if (trace == null) {
        Assert.fail("Registry deployment did not produce a confirmed transaction trace");
    }

    assert (registry.getAuctionRevenueAddress() == TAGITALSPACE_TESTNET_REVENUE_ADDRESS) throw 999;

    println("Registry deployed: {}", registry.address);
    println("Verified revenue recipient: {}", registry.getAuctionRevenueAddress());
    println("Claimable Registry refunds: {}", registry.getClaimableRefundTotal());
    println(
        "Sample item address (A123BC / region 77): {}",
        registry.getPlateItemAddress(
            beginCell().storeUint(0x413132334243, 48).endCell(),
            77,
        ),
    );
    println("Deployment trace: {}", trace);
}
