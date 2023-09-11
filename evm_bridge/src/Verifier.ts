import { Field } from 'o1js';
import { circuitMain, Circuit } from 'o1js';
import { createSRSFromJSON, SRS } from './SRS.js';

export class Verifier extends Circuit {
  @circuitMain
  static main() {
    let srs = createSRSFromJSON();
    let points: Field[] = [srs.h];
    let scalars: Field[] = [Field(0)];
  }

  static msm(points: Field[], scalars: []) {

  }
}
