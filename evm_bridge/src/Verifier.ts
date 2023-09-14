import { circuitMain, Circuit, Group, Scalar, Field } from 'o1js';
import { SRS } from './SRS.js';

let { h } = SRS.createFromJSON();

const z1 = Scalar.from(9140459199330635488539022482071352360057123086931083513302456950746879743855n);
const sg = new Group({ x: 7150761156930520555320873072173932897112225409642658953674970089964888546088n, y: 17188195103491218287333790399350281107383694033134889386035397860944298711813n })
const randBase = Scalar.from(1);
const negRandBase = randBase.neg();
const sgRandBase = Scalar.from(1);

const expected = new Group({ x: 15683840072078716790992059511892963252123661633363956975161924564815358836028n, y: 16211880226926008105967726776783409447539547553313354951819425946245139312475n });

export class Verifier extends Circuit {
  @circuitMain
  static main() {
    let points: Group[] = [h, sg];
    let scalars: Scalar[] = [Scalar.from(0), negRandBase.mul(z1).sub(sgRandBase)];

    Verifier.msm(points, scalars).assertEquals(expected);
  }

  // Naive algorithm
  static msm(points: Group[], scalars: Scalar[]) {
    let result = Group.zero;

    for (let i = 0; i < points.length; i++) {
      let point = points[i];
      let scalar = scalars[i];
      result = result.add(point.scale(scalar));
    }

    return result;
  }
}
