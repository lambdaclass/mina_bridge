import assert from 'assert';
import { readFileSync } from 'fs';
import { circuitMain, Circuit, Group, Scalar, Provable } from 'o1js';
import { SRS } from '../SRS';

let steps: bigint[][];
try {
  steps = JSON.parse(readFileSync("./src/steps.json", "utf-8"));
} catch (e) {
  steps = [];
}

let { g, h } = SRS.createFromJSON();

export class VerifierIndex {
    srs: SRS
    domain_size: number
    public: number
}

export class Verifier {
  static main(sg: Group, z1: bigint, expected: Group, debug: boolean) {
    let nonzero_length = g.length;
    let max_rounds = Math.ceil(Math.log2(nonzero_length));
    let padded_length = Math.pow(2, max_rounds);
    let padding = padded_length - nonzero_length;

    let points = [h];
    points = points.concat(g);
    points = points.concat(Array(padding).fill(Group.zero));

    let scalars = [0n];
    //TODO: Add challenges and s polynomial (in that case, using Scalars we could run out of memory)
    scalars = scalars.concat(Array(padded_length).fill(1n));
    assert(points.length == scalars.length, "The number of points is not the same as the number of scalars");

    points.push(sg);
    scalars.push(mod(-z1 - 1n));

    if (debug) {
      Verifier.msmDebug(points, scalars).assertEquals(expected);
    } else {
      Verifier.msm(points, scalars).assertEquals(expected);
    }
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

  // Naive algorithm (used for debugging)
  static msmDebug(points: Group[], scalars: bigint[]) {
    let result = Group.zero;

    if (steps.length === 0) {
      console.log("Steps file not found, skipping MSM check");
    }

    for (let i = 0; i < points.length; i++) {
      let point = points[i];
      let scalar = scalars[i];
      result = result.add(point.scale(scalar));

      if (steps.length > 0 && (result.x.toBigInt() != steps[i][0] || result.y.toBigInt() != steps[i][1])) {
        console.log("Result differs at step", i);
      }
    }

    return result;
  }
}

function mod(n: bigint) {
  return ((n % Scalar.ORDER) + Scalar.ORDER) % Scalar.ORDER;
}
