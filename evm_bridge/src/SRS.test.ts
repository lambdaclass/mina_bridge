import { Field } from "o1js";
import { SRS } from "./SRS";

test("Deserialize SRS and check fields", () => {
    let srs = SRS.createFromJSON();
    let first_g = srs.g[0];

    let expected_g_x = Field(0xf860fc1253c58c46f6c5afc51f0f66e7523ed4f8aa851370a9d55f8826441c12n);
    let expected_g_y = Field(0x708b02abd83f6dd966f7dd807761af08b14c4e32ebddc51835ea4712c039b421n);
    expect(first_g.x).toEqual(expected_g_x);
    expect(first_g.y).toEqual(expected_g_y);
    let expected_h_x = Field(0x012226265bceb2e5a8c78be27579a29c3636787563f2b4aa99c9016338602009n);
    let expected_h_y = Field(0x26bebc5e9c2420ce85ee05589b9a206a60f26561be419d9f506ae63ad8c44f31n);
    expect(srs.h.x).toEqual(expected_h_x);
    expect(srs.h.y).toEqual(expected_h_y);
});
