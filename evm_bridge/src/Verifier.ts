import assert from 'assert';
import { circuitMain, Circuit, Group, Scalar } from 'o1js';
import { SRS } from './SRS.js';

let { g, h } = SRS.createFromJSON();

const z1 = Scalar.from(8370756341770614687265652169950746150853295615521166276710307557441785774650n);
const sg = new Group({ x: 974375293919604067421642828992042234838532512369342211368018365361184475186n, y: 25355274914870068890116392297762844888825113893841661922182961733548015428069n });
const expected = new Group({ x: 23971162515526044551720809934508194276417125006800220692822425564390575025467n, y: 27079223568793814179815985351796131117498018732446481340536149855784701006245n });

export class Verifier extends Circuit {
  @circuitMain
  static main() {
    let nonzero_length = g.length;
    let max_rounds = Math.ceil(Math.log2(nonzero_length));
    let padded_length = Math.pow(2, max_rounds);
    let padding = padded_length - nonzero_length;

    let points = [h];
    points = points.concat(g);
    points = points.concat(Array(padding).fill(Group.zero));

    let scalars = [Scalar.from(0)];
    //TODO: Add challenges and s polynomial (in that case, using Scalars we could run out of memory)
    scalars = scalars.concat(Array(padded_length).fill(Scalar.from(1)));
    assert(points.length == scalars.length, "The number of points is not the same as the number of scalars");

    points.push(sg);
    scalars.push(z1.neg().sub(Scalar.from(1)));

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
