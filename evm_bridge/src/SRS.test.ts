import { Field } from "o1js";
import { SRS } from "./SRS";

test("Deserialize SRS and check fields", () => {
    let srs = SRS.createFromJSON();
    let first_g = srs.g[0];

    let expected_g_x = Field(24533576165769248459550833334830854594262873459712423377895708212271843679280n);
    let expected_g_y = Field(1491943283321085992458304042389285332496706344738505795532548822057073739620n);
    expect(first_g.x).toEqual(expected_g_x);
    expect(first_g.y).toEqual(expected_g_y);
    let expected_h_x = Field(15427374333697483577096356340297985232933727912694971579453397496858943128065n);
    let expected_h_y = Field(2509910240642018366461735648111399592717548684137438645981418079872989533888n);
    expect(srs.h.x).toEqual(expected_h_x);
    expect(srs.h.y).toEqual(expected_h_y);
});
