import { CircuitString, Field } from "o1js";
import { SRS } from "./SRS.js";

test("Deserialize point for y positive", () => {
    let serialized_point_y_pos = CircuitString.fromString("26fd31d1824baae274323cc4379bbefb51f445f0aef6a630b24afbf79f34c92600");
    let deserialized_point = SRS.decompressPoint(serialized_point_y_pos);
    let x = Field.from("0x17A7F8F327648386595EC53020B5A5B174B2851E3FAFF4CBFE5B8F8D47459382");
    let y = Field.from("0x229ED7CF112BB7D6B2CDB06BDC543092E8C16C721B6E7763B9EE29777CE7F240");

    expect(deserialized_point.x).toEqual(x);
    expect(deserialized_point.y).toEqual(y);
});
