import { circuitMain, Circuit, Group, Scalar, Field } from 'o1js';
import { SRS } from './SRS.js';

let { g, h } = SRS.createFromJSON();

const z1 = Scalar.from(11164968105101346800601138014004522679567438778713307333394634182972316008497n);
const sg = new Group({ x: 15278981249295424160498722087900196657161522262984020265396573104489152116709n, y: 4850314952377183854204710264495149520289203330774235803994549591326220970677n });
const expected = new Group({ x: 1147286326535894773798565427772816968384738437752833585359811205574455608001n, y: 14452503934711747476944141550942840832396802557030426136987723106749969725488n });

const randBase = Scalar.from(1);
const negRandBase = randBase.neg();
const sgRandBase = Scalar.from(1);

export class Verifier extends Circuit {
  // @circuitMain
  static main() {
    let nonzero_length = g.length;
    let max_rounds = Math.ceil(Math.log2(nonzero_length));
    let padded_length = Math.pow(2, max_rounds);
    let padding = padded_length - nonzero_length;

    let points = [h];
    console.log("points len:", points.length);
    points.concat(g);
    console.log("points len:", points.length);
    points.concat(Array(padding).fill(Group.zero));
    console.log("points len:", points.length);

    let scalars = Array(padded_length + 1).fill(Scalar.from(0));
    console.log("scalars len:", scalars.length);

    points.push(sg);
    console.log("points len:", points.length);
    scalars.push(negRandBase.mul(z1).sub(sgRandBase));
    console.log("scalars len:", scalars.length);

    let s = Array(g.length).fill(Scalar.from(1));
    console.log("s len:", s.length);
    for (let i = 0; i < s.length; i++) {
      let term = sgRandBase.mul(s[i]);
      scalars[i + 1] = scalars[i + 1].add(term);
      console.log("i:", i, "term:", term.toBigInt(), "s:", scalars[i + 1].toBigInt());
    }

    console.log("msm!");
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
