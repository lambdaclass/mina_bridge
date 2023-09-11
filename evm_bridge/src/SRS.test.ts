import { Field } from "o1js";
import { createSRSFromJSON } from "./SRS";

test("Deserialize SRS", () => {
    let srs = createSRSFromJSON();

    let expected_h_x = Field(0x012226265bceb2e5a8c78be27579a29c3636787563f2b4aa99c9016338602009n);
    let expected_h_y = Field(0x26bebc5e9c2420ce85ee05589b9a206a60f26561be419d9f506ae63ad8c44f31n);
    expect(srs.h.x).toEqual(expected_h_x);
    expect(srs.h.y).toEqual(expected_h_y);
});
