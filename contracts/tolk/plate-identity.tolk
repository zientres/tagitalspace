// TagitalSpace plate identity rules.
// The plate body is stored in canonical ASCII form.
// Region is a separate numeric identity component.

const TAGITALSPACE_PLATE_LENGTH = 6;
const TAGITALSPACE_MIN_REGION_CODE = 1;
const TAGITALSPACE_MAX_REGION_CODE = 999;

fun tagitalSpaceIsAllowedPlateLetter(value: int): bool {
    return value == 65 || value == 66 || value == 69 || value == 75
        || value == 77 || value == 72 || value == 79 || value == 80
        || value == 67 || value == 84 || value == 89 || value == 88;
}

fun tagitalSpaceIsPlateDigit(value: int): bool {
    return value >= 48 && value <= 57;
}

// Accepts only canonical six-byte ASCII: LDDDLL.
// Cyrillic input must be transliterated by the client before submission.
fun tagitalSpaceValidatePlateBody(plate: slice): bool {
    if (plate.remainingBitsCount() != TAGITALSPACE_PLATE_LENGTH * 8) {
        return false;
    }

    var chars = plate;
    val firstLetter = chars.loadUint(8);
    val firstDigit = chars.loadUint(8);
    val secondDigit = chars.loadUint(8);
    val thirdDigit = chars.loadUint(8);
    val secondLetter = chars.loadUint(8);
    val thirdLetter = chars.loadUint(8);

    return tagitalSpaceIsAllowedPlateLetter(firstLetter)
        && tagitalSpaceIsPlateDigit(firstDigit)
        && tagitalSpaceIsPlateDigit(secondDigit)
        && tagitalSpaceIsPlateDigit(thirdDigit)
        && tagitalSpaceIsAllowedPlateLetter(secondLetter)
        && tagitalSpaceIsAllowedPlateLetter(thirdLetter);
}

// Region codes are numeric and stored independently from the plate body.
// This validates the numeric domain; a country-specific allowlist can be
// layered on top without changing the identity format.
fun tagitalSpaceValidateRegionCode(regionCode: int): bool {
    return regionCode >= TAGITALSPACE_MIN_REGION_CODE
        && regionCode <= TAGITALSPACE_MAX_REGION_CODE;
}

// The identity key is a deterministic cell containing both components.
// Callers must validate both inputs before constructing this key.
fun tagitalSpaceBuildPlateIdentity(plate: slice, regionCode: int): cell {
    assert (tagitalSpaceValidatePlateBody(plate)) throw 710;
    assert (tagitalSpaceValidateRegionCode(regionCode)) throw 711;

    return beginCell()
        .storeSlice(plate)
        .storeUint(regionCode, 10)
        .endCell();
}
