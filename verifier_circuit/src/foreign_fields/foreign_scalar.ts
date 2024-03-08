import { Scalar, createForeignField } from "o1js";

export class ForeignScalar extends createForeignField(Scalar.ORDER).AlmostReduced { }

