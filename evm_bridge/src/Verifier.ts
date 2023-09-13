import { circuitMain, Circuit, Group, Scalar, Field } from 'o1js';
import { SRS } from './SRS.js';

let { g, h } = SRS.createFromJSON();

const z1 = 25941210464058333615640277621650698115212711614201964880539255585340602439563n;
const sg = new Group({ x: 13083261687194515069435447694875777772013102442934202017859940102123715707411n, y: 3304437928237879390637239761250612103836290340416580684668461108572943688529n });
const expected = new Group({ x: 25898394755259204300293837348855282619150839292818703595205424265266533863003n, y: 27621775263417330268828823966510023901196203314880122974412190362158599366097n });

const randBase = 1n;
const negRandBase = Scalar.from(randBase).neg().toBigInt();
const sgRandBase = 1n;

export class Verifier extends Circuit {
  @circuitMain
  static main() {
    let nonzero_length = g.length;
    let max_rounds = Math.ceil(Math.log2(nonzero_length));
    let padded_length = Math.pow(2, max_rounds);
    let padding = padded_length - nonzero_length;

    let points = [h];
    points.concat(g);
    points.concat(Array(padding).fill(Group.zero));

    let scalars = Array(padded_length + 1).fill(0n);

    points.push(sg);
    scalars.push(negRandBase * z1 - sgRandBase);

    let s = Array(g.length).fill(1n);
    for (let i = 0; i < s.length; i++) {
      let term = sgRandBase * s[i];
      scalars[i + 1] += term;
    }

    Verifier.msm(points, scalars).assertEquals(expected);
  }

  // Naive algorithm
  static msm(points: Group[], scalars: bigint[]) {
    let result = Group.zero;

    for (let i = 0; i < points.length; i++) {
      let point = points[i];
      let scalar = scalars[i];
      result = result.add(point.scale(scalar));
    }

    return result;
  }
}
