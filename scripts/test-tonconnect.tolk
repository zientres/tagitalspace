import "../.acton/io"
import "../.acton/prompts"
import "../.acton/emulation/network"
import "../.acton/emulation/scripts"
import "../.acton/testing/assert"

/// Diagnostic only: sends 0.01 testnet TON from the connected wallet back to itself.
/// This isolates TON Connect wallet approval from the larger Registry deployment payload.
fun main() {
    val wallet = scripts.wallet(promptWallet("Select the Testnet diagnostic wallet:"));

    println("Connected wallet: {}", wallet.address);
    println("A single self-transfer of 0.01 Testnet TON will be requested.");
    println("No contract will be deployed.");

    val message = createMessage({
        bounce: false,
        value: grams("0.01"),
        dest: wallet.address,
    });
    val result = net.send(wallet.address, message);
    val transaction = result.waitForFirstTransaction();

    if (transaction == null) {
        Assert.fail("TON Connect self-transfer was not confirmed on Testnet");
    }

    println("TON Connect diagnostic transaction confirmed: {}", transaction);
}
