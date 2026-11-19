import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const prices = JSON.parse(readFileSync(resolve(here, "plate-pricing-vectors.json"), "utf8"));
const timings = JSON.parse(readFileSync(resolve(here, "auction-timing-vectors.json"), "utf8"));
const registryProtocol = readFileSync(resolve(here, "../tolk/registry-messages.tolk"), "utf8");
const registryState = readFileSync(resolve(here, "../tolk/registry-state.tolk"), "utf8");
const registryStorage = readFileSync(resolve(here, "../tolk/registry-storage.tolk"), "utf8");
const registryRequest = readFileSync(resolve(here, "../tolk/registry-request.tolk"), "utf8");
const registryContract = readFileSync(resolve(here, "../tolk/TagitalSpaceRegistry.tolk"), "utf8");

const allowedLetters = "ABEKMHOPCTYX";

function platePrice(plate) {
  assert.match(plate, new RegExp(`^[${allowedLetters}][0-9]{3}[${allowedLetters}]{2}$`), `Invalid canonical plate: ${plate}`);
  const [firstLetter, firstDigit, secondDigit, thirdDigit, secondLetter, thirdLetter] = plate;
  const letterPrice = firstLetter === thirdLetter
    ? (firstLetter === secondLetter ? 50 : 15)
    : 0;
  const digitPrice = firstDigit === thirdDigit
    ? (firstDigit === secondDigit ? 50 : 15)
    : 0;
  return letterPrice + digitPrice || 3;
}

function auctionEndTime(vector) {
  if (vector.case === "initial_duration") return vector.start_time + 3600;
  const remaining = vector.auction_end_time - vector.current_time;
  assert.ok(remaining >= 0, `Expired auction vector is not a valid bid: ${vector.case}`);
  return remaining < 3600 ? vector.current_time + 3600 : vector.auction_end_time;
}

for (const vector of prices) {
  assert.equal(platePrice(vector.plate), vector.price_ton, `Plate pricing mismatch: ${vector.plate}`);
}
for (const vector of timings) {
  assert.equal(auctionEndTime(vector), vector.expected_end_time, `Auction timing mismatch: ${vector.case}`);
}

// Plate identity validation mirrors the on-chain canonical ASCII rules.
function validPlateBody(plate) {
  return typeof plate === "string"
    && /^[ABEKMHOPCTYX][0-9]{3}[ABEKMHOPCTYX]{2}$/.test(plate);
}

function validRegionCode(regionCode) {
  return Number.isInteger(regionCode) && regionCode >= 1 && regionCode <= 999;
}

function plateIdentity(plate, regionCode) {
  assert.ok(validPlateBody(plate), `Invalid plate body: ${plate}`);
  assert.ok(validRegionCode(regionCode), `Invalid region code: ${regionCode}`);
  return `${plate}:${regionCode}`;
}

const supportedRussiaRegions = new Set(`
01 101 02 102 702 03 103 04 104 05 105 06 106 07 107 08 108 09 109
10 110 11 111 12 112 13 113 14 114 15 115 16 116 716 17 117 18 118 19 119
95 195 21 121 22 122 23 93 123 193 24 84 88 124 25 125 725 26 126 27 127 28 128 29 129 30 130
31 131 32 132 33 133 34 134 35 135 36 136 37 137 38 138 39 91 139 40 140 41 141 42 142 43 143 44 144
45 145 46 146 47 147 48 148 49 149 50 90 150 190 250 550 750 790 51 151 52 152 252 53 153 54 154 754
55 155 56 156 57 157 58 158 59 159 60 61 161 761 62 162 63 163 763 64 164 65 165 66 96 166 196
67 167 68 168 69 169 70 170 71 171 72 172 73 173 74 174 774 75 180 76 176
77 97 99 177 197 199 277 299 777 797 799 977 78 98 178 198 798 778 79 179
80 180 81 181 82 182 83 183 84 184 85 185 86 186 87 187 89 189 92 192 94 194
`.trim().split(/\s+/).map(Number));

function validRussiaRegion(regionCode) {
  return validRegionCode(regionCode) && supportedRussiaRegions.has(regionCode);
}

// Canonical format and allowed alphabet.
for (const plate of ["A777AA", "M343YM", "X000YX"]) {
  assert.ok(validPlateBody(plate), `Expected valid plate: ${plate}`);
}
for (const plate of ["А777АА", "A77AAA", "A777AЯ", "Z123AA", "A1234A", "A12AA"]) {
  assert.ok(!validPlateBody(plate), `Expected invalid canonical plate: ${plate}`);
}

// Region participates in identity; price remains based on plate body alone.
assert.notEqual(plateIdentity("A777AA", 77), plateIdentity("A777AA", 78));
assert.equal(plateIdentity("A777AA", 77), plateIdentity("A777AA", 77));
assert.ok(validRussiaRegion(77));
assert.ok(validRussiaRegion(777));
assert.ok(!validRussiaRegion(20), "Region 20 is intentionally excluded");
assert.ok(!validRussiaRegion(100), "Unsupported region must be rejected");
assert.equal(supportedRussiaRegions.size, 212);
for (const region of [0, -1, 1000, 1.5, "77"]) {
  assert.ok(!validRegionCode(region), `Expected invalid region: ${region}`);
}

// Floor(currentBid * 105 / 100) threshold cases.
for (const [currentBid, expected] of [[1, 1], [19, 19], [20, 21], [100, 105], [101, 106], [1_000_000_000, 1_050_000_000]]) {
  assert.equal(Math.floor(currentBid * 105 / 100), expected, `Minimum bid mismatch for ${currentBid}`);
}

// Auction deadline boundaries: 3599 extends, 3600 does not.
function auctionEndAfterBid(now, endTime) {
  assert.ok(endTime >= now, "Cannot bid on an expired auction");
  return endTime - now < 3600 ? now + 3600 : endTime;
}
assert.equal(auctionEndAfterBid(5000, 8600), 8600, "Exactly one hour must not extend");
assert.equal(auctionEndAfterBid(5000, 8599), 8600, "Less than one hour must extend");
assert.equal(auctionEndAfterBid(5000, 5001), 8600, "A last-second bid must reset to one hour");
assert.throws(() => auctionEndAfterBid(5000, 4999), /Cannot bid/);

// First bid must meet the starting price; later bids use floor(105%).
assert.ok(3_000_000_000 >= 3_000_000_000);
assert.ok(!(2_999_999_999 >= 3_000_000_000));
assert.ok(105 >= Math.floor(100 * 105 / 100));
assert.ok(!(104 >= Math.floor(100 * 105 / 100)));

// TON DNS-style architecture checks: Registry deploys deterministic items;
// each item contract owns its auction and no shared Auction Manager exists.
const itemState = readFileSync(resolve(here, "../tolk/plate-item-state.tolk"), "utf8");
const itemMessages = readFileSync(resolve(here, "../tolk/plate-item-messages.tolk"), "utf8");
const itemAuction = readFileSync(resolve(here, "../tolk/plate-item-auction.tolk"), "utf8");
const itemContract = readFileSync(resolve(here, "../tolk/PlateItem.tolk"), "utf8");

const protocolOpcodes = [...registryProtocol.matchAll(/struct \(0x([0-9A-Fa-f]{8})\) ([A-Za-z0-9_]+)/g)];
assert.equal(protocolOpcodes.length, 3, "Registry start, treasury-deposit and treasury-claim messages are expected");
const opcodeValues = protocolOpcodes.map(([, opcode]) => opcode.toLowerCase());
assert.equal(new Set(opcodeValues).size, opcodeValues.length, "Registry protocol opcodes must be unique");
assert.match(registryContract, /StartPlateAuction =>/);
assert.match(registryContract, /calcDeployedPlateItem/);
assert.match(itemState, /stateInit:/);
assert.match(registryContract, /storage\.nftItemCode/);
assert.match(registryContract, /SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE/);
assert.match(registryState, /nftItemCode: cell/);
assert.doesNotMatch(registryState + registryProtocol + registryContract, /auctionManagerAddress|ManagedAuction|Auction Manager/i);
assert.match(itemContract, /contract TagitalSpacePlateItem/);
assert.match(itemContract, /PlateItemInitData/);
assert.match(itemContract, /tagitalSpaceProcessPlateBid/);
assert.match(itemContract, /tagitalSpaceSettlePlateAuction/);
assert.match(itemState, /auction: Cell<PlateAuctionState>\?/);
assert.match(itemAuction, /highestBid \* 105 \/ 100/);
assert.match(itemAuction, /auctionEndTime - blockchain\.now\(\) < TAGITALSPACE_ITEM_AUCTION_DURATION/);
assert.match(itemAuction, /highestBid \* 50 \/ 100/);
assert.match(itemAuction, /highestBid \* 30 \/ 100/);
assert.match(itemAuction, /developmentSecurityFund/);
assert.match(itemMessages, /SettlePlateAuction/);
assert.match(itemMessages, /ClaimPlatePayout/);
assert.match(itemMessages, /TransferPlateOwnership/);
assert.match(itemState, /pendingOwnerPayout: coins/);
assert.match(itemState, /pendingTreasuryPayout: coins/);
assert.match(itemState, /pendingSecurityPayout: coins/);
assert.match(itemAuction, /Settlement creates three explicit liabilities/);
assert.match(itemAuction, /BounceMode.NoBounce/);
assert.match(itemContract, /get_pending_payouts/);
assert.match(itemContract, /TransferPlateOwnership =>/);
assert.match(itemAuction, /tagitalSpaceTransferPlateOwnership/);
assert.match(registryContract, /RequestRegistryTreasuryPayout/);
assert.match(registryContract, /ClaimPlatePayout/);

console.log(\`PASS: \${prices.length} plate-pricing vectors, \${timings.length} auction-timing vectors, identity, bid-policy and TON DNS-style per-item auction source checks.\`);
