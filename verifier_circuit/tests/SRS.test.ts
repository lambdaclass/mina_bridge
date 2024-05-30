import { SRS } from "../src/SRS.ts";
import { ForeignBase } from "../src/foreign_fields/foreign_field.ts";

test("Deserialize SRS and check fields", () => {
    let srs = SRS.createFromJSON();
    let first_g = (srs.g[0]);

    let expected_g_x = ForeignBase.from("24533576165769248459550833334830854594262873459712423377895708212271843679280");
    let expected_g_y = ForeignBase.from("1491943283321085992458304042389285332496706344738505795532548822057073739620");
    expect(first_g.x.toBigInt().toString()).toEqual(expected_g_x.toBigInt().toString());
    expect(first_g.y.toBigInt().toString()).toEqual(expected_g_y.toBigInt().toString());
    let expected_h_x = ForeignBase.from("15427374333697483577096356340297985232933727912694971579453397496858943128065");
    let expected_h_y = ForeignBase.from("2509910240642018366461735648111399592717548684137438645981418079872989533888");
    expect(srs.h.x.toBigInt().toString()).toEqual(expected_h_x.toBigInt().toString());
    expect(srs.h.y.toBigInt().toString()).toEqual(expected_h_y.toBigInt().toString());
});
