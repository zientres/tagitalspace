// TagitalSpace plate pricing rules.
// Input: six canonical ASCII characters (Russian letters transliterated).
// The region code is intentionally excluded.
// Return value is denominated in nanotons.

const TAGITALSPACE_ONE_TON = 1_000_000_000;

fun tagitalSpaceIsPlateLetter(value: int): bool {
    return value == 65 || value == 66 || value == 69 || value == 75
        || value == 77 || value == 72 || value == 79 || value == 80
        || value == 67 || value == 84 || value == 89 || value == 88;
}

fun tagitalSpaceIsDigit(value: int): bool {
    return value >= 48 && value <= 57;
}

fun tagitalSpacePlateStartPrice(plate: slice): int {
    assert (plate.bits() == 48) throw 700;

    var chars = plate;
    val firstLetter = chars.loadUint(8);
    val firstDigit = chars.loadUint(8);
    val secondDigit = chars.loadUint(8);
    val thirdDigit = chars.loadUint(8);
    val secondLetter = chars.loadUint(8);
    val thirdLetter = chars.loadUint(8);

    assert (
        tagitalSpaceIsPlateLetter(firstLetter)
        && tagitalSpaceIsDigit(firstDigit)
        && tagitalSpaceIsDigit(secondDigit)
        && tagitalSpaceIsDigit(thirdDigit)
        && tagitalSpaceIsPlateLetter(secondLetter)
        && tagitalSpaceIsPlateLetter(thirdLetter)
    ) throw 701;

    var lettersPrice = 0;
    if (firstLetter == thirdLetter) {
        if (firstLetter == secondLetter) {
            lettersPrice = 50;
        } else {
            lettersPrice = 15;
        }
    }

    var digitsPrice = 0;
    if (firstDigit == thirdDigit) {
        if (firstDigit == secondDigit) {
            digitsPrice = 50;
        } else {
            digitsPrice = 15;
        }
    }

    val specialPrice = lettersPrice + digitsPrice;
    if (specialPrice == 0) {
        return 3 * TAGITALSPACE_ONE_TON;
    }
    return specialPrice * TAGITALSPACE_ONE_TON;
}
