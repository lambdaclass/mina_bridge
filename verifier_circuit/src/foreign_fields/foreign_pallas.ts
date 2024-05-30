import { FieldBn254, createForeignCurveBn254 } from '../../o1js/src/index.ts';

const p = 0x40000000000000000000000000000000224698fc094cf91b992d30ed00000001n;
const q = 0x40000000000000000000000000000000224698fc0994a8dd8c46eb2100000001n;

const pallasGeneratorProjective = {
    x: 1n,
    y: 12418654782883325593414442427049395787963493412651469444558597405572177144507n,
};

const b = 5n;
const a = 0n;

const pallasEndoBase =
    20444556541222657078399132219657928148671392403212669005631716460534733845831n;

const pallasEndoScalar =
    26005156700822196841419187675678338661165322343552424574062261873906994770353n;

export class ForeignPallas extends createForeignCurveBn254({
    name: 'Pallas',
    modulus: p,
    order: q,
    generator: pallasGeneratorProjective,
    b,
    a,
    endoBase: pallasEndoBase,
    endoScalar: pallasEndoScalar,
}) {
    static sizeInFields() {
        return ForeignPallas.provable.sizeInFields();
    }

    static fromFields(fields: FieldBn254[]) {
        return ForeignPallas.provable.fromFields(fields) as ForeignPallas;
    }

    static toFields(one: ForeignPallas) {
        return ForeignPallas.provable.toFields(one);
    }

    toFields() {
        return ForeignPallas.toFields(this);
    }

    static assertEquals(one: ForeignPallas, other: ForeignPallas) {
        one.x.assertEquals(other.x);
        one.y.assertEquals(other.y);
    }
}

export function pallasZero(): ForeignPallas {
    return new ForeignPallas({ x: BigInt(0), y: BigInt(0) });
}
