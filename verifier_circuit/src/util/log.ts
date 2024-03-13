import { ForeignFieldBn254, Provable } from "o1js";

export function logField<T extends ForeignFieldBn254>(message: string, element: T) {
    Provable.asProverBn254(() => console.log(message, element.toBigInt()));
}
