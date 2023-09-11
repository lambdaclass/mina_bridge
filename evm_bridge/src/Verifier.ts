import { circuitMain, Circuit, Field, Group, Scalar } from 'o1js';
import { SRS } from './SRS.js';

console.log("O1JS ORDER:", Field.ORDER.toString(16).toUpperCase());
let srs = SRS.createFromJSON();

export class Verifier extends Circuit {
  @circuitMain
  static main() {
    let points: Group[] = [srs.h];
    let scalars: Scalar[] = [Scalar.from(0)];

    this.msm(points, scalars).assertEquals(Group.zero);
  }

  // Naive algorithm
  static msm(points: Group[], scalars: Scalar[]) {
    let result = Group.zero;

    for (let i = 0; i < points.length; i++) {
      let point = points[i];
      let scalar = scalars[i];
      result.add(point.scale(scalar));
    }

    return result;
  }
}
