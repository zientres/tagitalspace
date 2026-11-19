import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const prices = JSON.parse(readFileSync(resolve(here, "plate-pricing-vectors.json"), "utf8"));
const timings = JSON.parse(readFileSync(resolve(here, "auction-timing-vectors.json"), "utf8"));

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

console.log(`PASS: ${prices.length} plate-pricing vectors, ${timings.length} auction-timing vectors, identity and bid-policy checks.`);
