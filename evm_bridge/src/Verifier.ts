import { Field } from 'o1js';
import { circuitMain, Circuit } from 'o1js';
import { Point } from './Point.js';
import { SRS } from './SRS.js';

export class Verifier extends Circuit {
  @circuitMain
  static main() {
    let srs = SRS.createFromJSON();
    let points: Point[] = [srs.h];
    let scalars: Field[] = [Field(0)];
  }

  static msm(points: Field[], scalars: []) {

  }
}
