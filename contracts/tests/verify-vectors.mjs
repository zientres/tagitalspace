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

console.log(`PASS: ${prices.length} plate-pricing vectors and ${timings.length} auction-timing vectors.`);
